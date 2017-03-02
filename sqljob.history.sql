
--SELECT A.JobName, REPLACE(A.JobName, 'Retranslate', '') Manager, A.JobStart, A.JobEnd,
--RIGHT('00' + CAST( hrs AS VARCHAR), 2) + ':' +
--RIGHT('00' + CAST( MINS - (hrs * 60) AS VARCHAR), 2) + ':' +
--RIGHT('00' + CAST( SECS - (MINS * 60) AS VARCHAR), 2) DURATION, secs, mins, hrs
--FROM (
--	SELECT distinct A.JobName, A.JobStart, JobEnd, 
--	DATEDIFF(second, jobstart, isnull(jobend, getdate())) secs,
--	DATEDIFF(second, jobstart, isnull(jobend, getdate())) / 60 mins,
--	(DATEDIFF(second, jobstart, isnull(jobend, getdate())) / 60) / 60 hrs
--	FROM (
--		SELECT J.name JobName, 
--		CONVERT(DATETIME,
--			CONVERT(NVARCHAR(4),H.run_date / 10000) + N'-' + 
--			CONVERT(NVARCHAR(2),(H.run_date % 10000)/100)  + N'-' +
--			CONVERT(NVARCHAR(2),H.run_date % 100) + N' ' +        
--			CONVERT(NVARCHAR(2),H.run_time / 10000) + N':' +        
--			CONVERT(NVARCHAR(2),(H.run_time % 10000)/100) + N':' +        
--			CONVERT(NVARCHAR(2),H.run_time % 100),
--		120) JobStart, 
--		DATEADD(SECOND, ((H.run_duration/10000) * 3600) + ((H.run_duration/100%100)*60) + 
--		(H.run_duration%100), 
--		CONVERT(DATETIME,
--			CONVERT(NVARCHAR(4),H.run_date / 10000) + N'-' + 
--			CONVERT(NVARCHAR(2),(H.run_date % 10000)/100)  + N'-' +
--			CONVERT(NVARCHAR(2),H.run_date % 100) + N' ' +        
--			CONVERT(NVARCHAR(2),H.run_time / 10000) + N':' +        
--			CONVERT(NVARCHAR(2),(H.run_time % 10000)/100) + N':' +        
--			CONVERT(NVARCHAR(2),H.run_time % 100),
--		120)) JobEnd,
--		H.run_status JobStatus
--		FROM msdb.dbo.sysjobs J
--		INNER JOIN msdb.dbo.sysjobsteps S ON J.job_id = S.job_id
--		INNER JOIN msdb.dbo.sysjobhistory H ON S.job_id = H.job_id AND S.step_id = H.step_id AND H.step_id <> 0
--		where j.name != 'syspolicy_purge_history'
--		UNION
--		SELECT J.name JobName, JA.run_requested_date JobStart, NULL JobEnd, -1 JobStatus 
--		FROM msdb.dbo.sysjobs J 
--		INNER JOIN msdb.dbo.sysjobactivity JA ON J.job_id = JA.job_id 
--		WHERE JA.run_requested_date IS NOT NULL AND JA.stop_execution_date IS NULL and j.name != 'syspolicy_purge_history'
--	) A 
--) A
--ORDER BY A.JobName 


;WITH cte_hist AS (
	SELECT H.job_id, j.name job_name,
	CONVERT(DATETIME,
		CONVERT(NVARCHAR(4),H.run_date / 10000) + N'-' + 
		CONVERT(NVARCHAR(2),(H.run_date % 10000)/100)  + N'-' +
		CONVERT(NVARCHAR(2),H.run_date % 100) + N' ' +        
		CONVERT(NVARCHAR(2),H.run_time / 10000) + N':' +        
		CONVERT(NVARCHAR(2),(H.run_time % 10000)/100) + N':' +        
		CONVERT(NVARCHAR(2),H.run_time % 100),
	120) job_start, SUM(((H.run_duration/10000) * 3600) + ((H.run_duration/100%100)*60) + (H.run_duration%100)) run_duration
	FROM msdb.dbo.sysjobhistory H
	INNER JOIN msdb.dbo.sysjobs J ON H.job_id = J.job_id
	INNER JOIN msdb.dbo.sysjobsteps S ON J.job_id = S.job_id AND H.step_id = S.step_id
	where j.name != 'syspolicy_purge_history' AND H.run_status = 1
	GROUP BY H.job_id, 
	CONVERT(DATETIME,
		CONVERT(NVARCHAR(4),H.run_date / 10000) + N'-' + 
		CONVERT(NVARCHAR(2),(H.run_date % 10000)/100)  + N'-' +
		CONVERT(NVARCHAR(2),H.run_date % 100) + N' ' +        
		CONVERT(NVARCHAR(2),H.run_time / 10000) + N':' +        
		CONVERT(NVARCHAR(2),(H.run_time % 10000)/100) + N':' +        
		CONVERT(NVARCHAR(2),H.run_time % 100),
	120), j.name
), 
cte_last AS (
	SELECT H.job_id, MAX(H.job_start) job_start
	FROM cte_hist H
	GROUP BY H.job_id
),
cte_run AS(
	SELECT J.job_id, CAST(DateAdd(minute, DateDiff(minute, 0, JA.run_requested_date), 0) AS smalldatetime) job_start
	FROM msdb.dbo.sysjobs J 
	INNER JOIN msdb.dbo.sysjobactivity JA ON J.job_id = JA.job_id 
	WHERE JA.run_requested_date IS NOT NULL AND JA.stop_execution_date IS NULL
)
SELECT REPLACE(REPLACE(H.job_name, 'RetranslateManager_', ''), 'Retranslate', '') job_manager,
CASE WHEN H.job_name LIKE 'RetranslateManager_%' THEN 2 ELSE 1 END job_ver,
H.job_name, 
CASE WHEN P.job_id IS NOT NULL THEN 'RUNNING' ELSE '' END job_status, 
H.job_start, 
CASE WHEN P.job_id IS NOT NULL THEN NULL ELSE DATEADD(SECOND, H.run_duration, H.job_start) END job_end,
H.run_duration, 
RIGHT('00' + CAST( ((H.run_duration / 60) / 60) AS VARCHAR), 2) + ':' +
RIGHT('00' + CAST( (H.run_duration / 60) - (((H.run_duration / 60) / 60) * 60) AS VARCHAR), 2) + ':' +
RIGHT('00' + CAST( H.run_duration - ((H.run_duration / 60) * 60) AS VARCHAR), 2) run_time
FROM cte_hist H
INNER JOIN cte_last L ON H.job_id = L.job_id AND H.job_start = L.job_start
LEFT OUTER JOIN cte_run P ON H.job_id = P.job_id AND CAST(DateAdd(minute, DateDiff(minute, 0, H.job_start), 0) AS smalldatetime) = P.job_start
ORDER BY job_manager, job_ver

--SELECT J.job_id, j.name, JA.run_requested_date job_start
--	FROM msdb.dbo.sysjobs J 
--	INNER JOIN msdb.dbo.sysjobactivity JA ON J.job_id = JA.job_id 
--	WHERE JA.run_requested_date IS NOT NULL AND JA.stop_execution_date IS NULL
	
	 
