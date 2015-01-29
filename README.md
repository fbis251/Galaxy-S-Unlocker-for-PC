Galaxy S Unlocker for PC
========================

Windows/Linux Download
----------------------
You can download a zip file containing binaries for Windows and Linux here:

https://github.com/fbis251/Galaxy-S-Unlocker-for-PC/releases

Description
-----------

Gets the unlock code and performs a carrier lock/unlock for nv_data.bin files for Galaxy S (first
generation) series phones. The program has the option to write both a locked and an unlocked version
of the nv_data.bin file, which you can copy to the device's EFS partition by hand.

This is a rewrite in the D Programming Language of my
[C Unlock Code Finder](https://github.com/fbis251/sgs4g-unlock-code-finder). This program also
includes the ability to write both a locked and unlocked version of the nv_data.bin file.

Note that this is meant to be run on a computer and not the device itself. Although I haven't tried
it myself, the program uses only the standard Phobos D libraries and should theoretically cross
compile to ARM with no issues, assuming you use the correct cross compiler.

Supported Devices
-----------------
Theoretically any first generation Galaxy S series phone that uses an nv_data.bin file in the EFS
partition, that has the same unlock procedure as the Samsung Vibrant is supported.

Notes
-----
I have only tested this with nv_data.bin files from the Galaxy S 4G SGH-T959V and SGH-T959W.

As always, when performing any destructive operation on your device, **MAKE A BACKUP**.

The program tries to mitigate accidental errors by only writing to new files and never to the
original nv_data.bin file.

Usage
-----

    Usage: ./unlocker [OPTION] <filename>
    Arguments:
            filename (optional)
                    Looks for nv_data.bin in the current directory by default
    Options:
            -h, --help   Display this help and exit
            -w, --write  Output nv_data_locked.bin and nv_data_unlocked.bin
                         to the current directory and exit


### Detailed Usage Descriptions
    ./unlocker
With no other options, the program will try to read the unlock code from an nv_data.bin file
residing in the current directory. It will print the unlock code and the current lock status to the
screen and then exit.

    ./unlocker -w
Writes out locked and unlocked versions of the nv_data.bin file to the current directory. This
creates two new files in the current directory, nv_data_unlocked.bin and nv_data_locked.bin. You can
then rename the version of the file you want to use (unlocked or locked) to nv_data.bin before
transferring the file back to
the phone.

    ./unlocker /path/to/nv_data.bin
Uses the nv_data.bin file at the specified path. This can be combined with the `-w` flag as above.

Compiling
---------

    # Change to the cloned source code directory, then run one of the following
    cd /path/to/source_code

    # Compile with the Digital Mars D compiler
    dmd unlocker.d
    # or with the GNU D Compiler
    gdc -o unlocker unlocker.d
    # You can also run the program directly if you have the rdmd environment variable set
    ./unlocker.d

License
-------
Please see LICENSE.md for details
