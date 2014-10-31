#!/bin/sh
export PATH=$PATH:/usr/local/bin:/usr/bin
lckfile=/tmp/SeaFlow_RT.lock
if shlock -f ${lckfile} -p $$
then
echo "cron job starting at $(date)"
rm ~/cron_job.out
Rscript ~/popcycle-master/popcycle/executable_scripts/copy_file.R >& ~/cron_job.out
python ~/popcycle-master/popcycle/executable_scripts/fix_sfl_newlines.py >> ~/cron_job.out 2 >& 1
python ~/popcycle-master/popcycle/executable_scripts/fix_sfl.py >> ~/cron_job.out 2 >& 1
Rscript ~/popcycle-master/popcycle/executable_scripts/cron_job.R >> ~/cron_job.out 2 >& 1
rm ${lckfile}
else
echo "cron job did not run, lock ${lckfile} already held by $(cat ${lckfile})"
fi