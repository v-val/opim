# opim
Ownership and permissions management tool for VCS-tracked files.
## Description
VCS rarely have native provision for storing and recovering ownership and permissions info (OPI).

`opim.pl` helps to fill this gap.

First, you run `opim.pl` to collect OPI from filesystem and save it to file.

Then, when deploying files back to filesystem from repository, you run `opim.pl` again
to read saved OPI from file and restore it to deployed files providing same
ownership and permissions as were in the original filesystem.
## Usage
Collect OPI from filesystem and save to file:
```
opim.pl [-{i|x} ignore_pattern] [-d directory] [-o] [-f file]
```
Restore OPI from file to target directory:
```
opim.pl -R [-n] [-f file] [-d directory]
```
### Common options
`-d` directory to read OPI from or restore to.  
   Default is current directory.

`-f` file to store OPI to or read from.  
   Default is `.opinfo`
### Options affecting OPI collection:
`-i` add pattern to ignore.  
   Can be used multiple times.  
   Default is to ignore `.git`.

`-x` replace default ignore patterns.  
   Can be used multiple times.
