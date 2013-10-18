The aims of this project is to log information about IO on system, disks and files on zpool.
This way, you can have a global view of all I/O occuring on your zpool. By better understanding the 
load, you can increase performance by tuning it.

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
