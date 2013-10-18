#!/usr/sbin/dtrace -s
# pragma D option quiet
/*
 Author         : Szczepanski Adam
 Mail           : spoown@gmail.com
*/
/*
 * The script will show the number of read/write syscall made on each filesystem specified.
 * This way we can have an overview of which fs is the most used,
 * and may be re-distribute the load across the filesystem.
 *
 * Adding a section to see latency on all disk dedicated of a zpool, and see easily average respond time on these disk.
 */

dtrace:::BEGIN
{
	/* As we are computing stat for each minutes, we need to specify
	 * the number of minutes the script should run.
	 * By default, the script will run 1 fully day.
	 * 60 * 24 = 1440 minutes in a full day.
	 * x * 60 * 24 = x days of full monitoring.
	 * 5 days = 7200 minutes.
	 * 8 hours= 480  minutes.
	 */
        i = $1;
}

/*
 * If we want the read syscall made by a db only, and not all db.
 * The best should be to filter only process with the following name :
 * oracleDB_SID (LOCAL=NO)
 * DTrace predicate use, should be : curpsinfo->pr_psargs == "oracleDB_SID (LOCAL=NO)"
 * But actually, as it does not represent all process of the DB, smon, pmon, ... are also present.
 * The best way to ensure that, should be to filter all the fs that need to be investigated by the db.
 * actually, all the data directory : data01, data02, data03, ...
 * To filter more the data, we specify the PID of the process of the zpool doing the read/write on all the filesystem.
 * So, in this case, we suppose that all filesystem are in the same zpool.
 */
syscall::pread:entry
/* execname == "oracle" && fds[arg0].fi_fs == "lofs"  */
	/  fds[arg0].fi_mount == "/filesystem/where/db/are/data01"
	|| fds[arg0].fi_mount == "/filesystem/where/db/are/data02"
	|| fds[arg0].fi_mount == "/filesystem/where/db/are/data03"
	|| pid == 140 /
{
        /* Make an array for each file system, and count each read done on those filesystem. */
        /* Make a plot of those reads -> We will see the filesystem the most used. */
        @readFS["read_fs_count",fds[arg0].fi_mount] = count();
	self->ts = timestamp;
        self->mount_point_name = fds[arg0].fi_mount;
        self->type_operation = "read";
	/* Seeing where the IO goes on a specific filesystem. */
	/* This logging still needs to be read and handled properly, to see repartition of IO on files of the filesystem. */
	@readFileCount[ "read_file_count",fds[arg0].fi_pathname ] = count();
}

syscall::pread:return
/ self->ts && self->type_operation == "read" /
{
        /* Average read time in ms. */
        @avgRead["avg_read_time",self->mount_point_name] = avg( ( timestamp - self->ts ) / 1000000 );
        /* Seeing the distribution plot of the read. */
        @distributionRead[self->mount_point_name] = quantize( ( timestamp - self->ts ) / 1000000 );
        self->ts = 0;
        self->mount_point_name = 0;
        self->type_operation = 0;
}

syscall::pwrite:entry
/* execname == "oracle" && fds[arg0].fi_fs == "lofs"  */
	/  fds[arg0].fi_mount == "/filesystem/where/db/are/data01"
	|| fds[arg0].fi_mount == "/filesystem/where/db/are/data02"
	|| fds[arg0].fi_mount == "/filesystem/where/db/are/data03"
	|| pid == 140 /
{
        /* Make an array for each file system, and count each write done on those filesystem. */
        /* Make a plot of those write -> We will see the filesystem the most used. */
        @writeFS["write_fs_count",fds[arg0].fi_mount] = count();
        self->ts = timestamp;
        self->mount_point_name = fds[arg0].fi_mount;
        self->type_operation = "write";
	@writeFileCount[ "write_file_count",fds[arg0].fi_pathname ] = count();
}

syscall::pwrite:return
/ self->ts && self->type_operation == "write" /
{
        /* Average write time in ms. */
        @avgWrite["avg_write_time",self->mount_point_name] = avg( ( timestamp - self->ts ) / 1000000 );
        /* Seeing the distribution plot of the write. */
        @distributionWrite[self->mount_point_name] = quantize( ( timestamp - self->ts ) / 1000000 );
        self->ts = 0;
        self->mount_point_name = 0;
        self->type_operation = 0;
}

io:::start
/* 164 if the pid of process dispatching all read/write on the zpool for DB data. */
/ pid == 140 /
{
	/* Thanks to dtrace books of brandon greg, got the starting point for this probe... */
        start_time[arg0] = timestamp;
}

io:::done
/this->start = start_time[arg0]/
{
        this->delta = (timestamp - this->start) / 1000;
	/* Seeing the latency distribution of each disk of the zpool */
        @latencyDisk_ZPOOL[args[1]->dev_statname, args[1]->dev_major,
        args[1]->dev_minor] = quantize(this->delta);
	/* Recording the average response time for each disk of the zpool. */
        @avgDisk_ZPOOL["Average respond time",args[1]->dev_statname, args[1]->dev_major,
        args[1]->dev_minor] = avg(this->delta);
	/* Recording the number of IO occuring on each disk of the zpool. */
        @sumDisk_ZPOOL["number of IO",args[1]->dev_statname, args[1]->dev_major,
        args[1]->dev_minor] = count();
	/* Re-setting the mark for the disk studied. */
        start_time[arg0] = 0;
}

profile:::tick-60s
/ i > 0 /
{
	current_time = walltimestamp;
        printf("\n");
	printf("++ Read section BEGIN ++\n");
        printf("  File system Name              -       Number of read made on lofs \n");
        printf("\n");
        printf("Read count - getting the top 50 \n");
        printf("\n ");
	/* Keeping only the 50 most used. */
        trunc(@readFS,50);
        printa(@readFS);
        trunc(@readFS);
        printf("\n");
        printf("Average time [ in ms ] for a read syscall the specified mount moint : \n");
        printf("\n");
        printa(@avgRead);
	trunc(@avgRead);
        printf("\n");
        printf("Distribution plot of the read syscall of each mount point used during this sample\n");
        printf("\n");
        printa(@distributionRead);
	trunc(@distributionRead);
        printf("\n");
	printf("Distribution of the read on each file\n");
        printf("\n");
	/* Keeping only the 50 most used. */
	trunc(@readFileCount,50);
	printa(@readFileCount);
	trunc(@readFileCount);
        printf("\n");
	printf("Current time : %Y\n",current_time);
	printf("++ Read section END ++\n");
        printf("\n");
        printf("###########################################################################\n");
        printf("###########################################################################\n");
        printf("###########################################################################\n");
	printf("\n");
	printf("++ Write section BEGIN ++\n");
        printf("  File system Name              -       Number of write made on lofs \n");
        printf("\n");
        printf("Write count - getting the top 50 \n");
        printf("\n ");
	/* Keeping only the 50 most used. */
        trunc(@writeFS,50);
        printa(@writeFS);
        trunc(@writeFS);
        printf("\n");
        printf("Average time [ in ms ] for a write syscall the specified mount moint : \n");
        printf("\n");
        printa(@avgWrite);
	trunc(@avgWrite);
        printf("\n");
        printf("Distribution plot of the write syscall of each mount point used during this sample\n");
        printf("\n");
        printa(@distributionWrite);
	trunc(@distributionWrite);
        printf("\n");
	printf("Distribution of the write on each file\n");
        printf("\n");
	/* Keeping only the 50 most used. */
	trunc(@writeFileCount,50);
	printa(@writeFileCount);
	trunc(@writeFileCount);
        printf("\n");
        printf("Section for latency and average respong time for disks on zpool. \n");
        printf("\n");
	printa(@latencyDisk_ZPOOL);
	printa(@avgDisk_ZPOOL);
	printa(@sumDisk_ZPOOL);
	/* Resetting value for the next loop. */
	trunc(@latencyDisk_ZPOOL);
	trunc(@avgDisk_ZPOOL);
	trunc(@sumDisk_ZPOOL);
        printf("\n");
	printf("Current time : %Y\n",current_time);
	printf("++ Write section END ++\n");
        printf("\n");
        printf("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
	printf("++ NEXT RUN IS BELOW FOR READ AND WRITE CALL		            +++\n");
        printf("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
        i = i - 1;
}

profile:::tick-15s
/ i == 0 /
{
        exit(0);
}
