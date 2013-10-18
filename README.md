The aims of this project is to log information about I/O on filesystem, disks and files of a zpool.
This way, you can have a global view of all I/O occuring on your zpool. By better understanding the 
load, you can increase performance by tuning it.

You can imagine that if you known where the I/O goes on a filesystem (which files), you can re-balance the files accross different filesystem where the load is less on them.

The script is done with dtrace. So far, it logs number of I/O occuring on :
- filesystems
- files
- disks

more over, it provides also average read/write times on :
- filesystems
- disks [ no distinction between read/write in this case]

You can find also distribution of read/write time on :
- filesystem (in ms)
 
you can see also distribution for disks but no distinction is made between read/write.

# Important
You need to customize the script with your need, I mean to put there the name of your filesystem that you want to be monitored, and the pid of the zpool where the filesystems are. As from lines 41 and 71 in the script.

Usage :
* ./io-performances.d TOTAL_TIME

Example :
* ./io-performances.d 60

Meaning the script will run for a total of 60 minutes.
