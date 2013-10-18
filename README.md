
The aims of this project is to log information about IO on filesystem and files.

The script is done with dtrace. So far, it logs number of I/O occuring on :
- filesystems
- files
- disks

more over, it provides also average read/write times on :
- filesystems
- disks [ no distinguion between read/write in this case]

