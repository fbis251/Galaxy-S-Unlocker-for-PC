#!/usr/bin/env rdmd
/**
 *
 * Description: Gets the unlock code and performs a carrier lock/unlock for nv_data.bin files for
 *              Galaxy S (first generation) series phones. The program has the option to write
 *              both a locked and an unlocked version of the nv_data.bin file, which you can
 *              copy to the device's EFS partition by hand.
 * Author:      $(LINK http://fernandobarillas.com) Fernando Barillas @FBis251
 * Date:        Jan 28, 2015
 * Copyright:   (c) 2015 Fernando Barillas
 * License:     $(LINK http://opensource.org/licenses/MIT) The MIT License
 * Version:     1.0
 * History:
 *     Jan 28, 2015 -- Initial release
 *
 */
module unlocker;

import std.stdio;
import std.file;
import std.getopt;

enum string NV_DATA_PATH  = "nv_data.bin";
enum string UNLOCKED_PATH = "nv_data_unlocked.bin";
enum string LOCKED_PATH   = "nv_data_locked.bin";
enum uint   CODE_LOCATION = 0x1469;            // Magic byte location for lock status + ASCII code
enum uint   CODE_LENGTH   = 8;                 // How many bytes are the lock status + ASCII code?
enum uint   CODE_OFFSET   = CODE_LOCATION + 5; // ASCII unlock code compared to CODE_LOCATION
enum uint   LOCK_OFFSET   = CODE_LOCATION;     // Offset to the lock/unlock byte
enum ubyte  UNLOCKED      = 0x0;               // 0 byte signifies the phone is unlocked
enum ubyte  LOCKED        = 0x1;               // 1 byte signifies the phone is locked
enum uint   FIRST_BYTE    = 0xFF;              // The first byte of the pattern, used for validation
enum int    EXIT_SUCCESS  = 0;                 // Exit status for failure
enum int    EXIT_FAILURE  = 1;                 // Exit status for failure
enum char   ASCII_0       = '0';               // Used to check validity of unlock code
enum char   ASCII_9       = '9';               // Used to check validity of unlock code

// Runtime variables set by passed in options
bool DEBUG       = false;
bool PRINT_USAGE = false;
bool DO_WRITE    = false;

/**
 * Reads options passed in from the command line, in addition to the optional path to an nv_data.bin
 * file.
 *
 * Returns:
 *     Exit status code 0 if all operations completed successfully, 1 otherwise.
 */
int main(string[] arguments) {

    try {
        getopt(arguments,
            "x",       &DEBUG,
            "help|h",  &PRINT_USAGE,
            "write|w", &DO_WRITE,
        );
    } catch (Exception e) {
        stderr.writefln("%s\n", e.msg);
        printUsage(arguments[0]);
        return EXIT_FAILURE;
    }

    if (PRINT_USAGE) {
        printUsage(arguments[0]);
        return EXIT_SUCCESS;
    }

    // Read in the file
    ubyte[] nvDataBytes = readFile((arguments.length == 2) ? arguments[1] : NV_DATA_PATH);

    if (nvDataBytes == null) {
        return EXIT_FAILURE;
    }

    // Print out the file details
    printUnlockCode(nvDataBytes);
    printLockStatus(nvDataBytes);

    // Write out the locked and unlocked files
    if (DO_WRITE) {
        if (!writeFile(UNLOCKED, UNLOCKED_PATH, nvDataBytes)) {
            return EXIT_FAILURE;
        } else {
            writefln("Successfully wrote %s file", UNLOCKED_PATH);
        }

        if (!writeFile(LOCKED, LOCKED_PATH, nvDataBytes)) {
            return EXIT_FAILURE;
        } else {
            writefln("Successfully wrote %s file", LOCKED_PATH);
        }
    }

    return EXIT_SUCCESS;
}

/**
 * Prints the usage of the program and its options.
 *
 * Parameters:
 *     programPath  The path of the current executable. This is usually array index 0 of the
 *                  passed in arguments to main().
 */
void printUsage(string programPath) {
    stderr.writefln("Usage: %s [OPTION] <filename>", programPath);

    stderr.writefln("Arguments:");
    stderr.writefln("\tfilename (optional)");
    stderr.writefln("\t\tLooks for %s in the current directory by default", NV_DATA_PATH);

    stderr.writefln("Options:");
    stderr.writefln("\t-h, --help   Display this help and exit");
    stderr.writefln("\t-w, --write  Output nv_data_locked.bin and nv_data_unlocked.bin");
    stderr.writefln("\t             to the current directory and exit");
}

/**
 * Reads an nv_data.bin file from the filesystem into memory. It performs validation of the input
 * file using validateNvDataFile().
 *
 * Parameters:
 *     filename     The path to the file to read into memory.
 * Returns:
 *     The read in file in ubyte[] form.
 */
ubyte[] readFile(string filename) {
    // Make sure the file exists before trying to open it
    if (!exists(filename)) {
        stderr.writefln("File does not exist: %s", filename);
        return null;
    }

    if (DEBUG) {
        ulong filesize = getSize(filename);
        writefln("Filesize: %d", filesize);
    }

    // Read the file into memory
    ubyte[] nvDataFile;
    try {
        nvDataFile = cast(ubyte[]) read(filename);
    } catch (FileException e) {
        stderr.writeln("Error while reading file");
        stderr.writeln(e.msg);
        return null;
    }

    if (DEBUG) {
        writefln("Array length: %d", nvDataFile.length);
    }

    // Perform validation of the file since nv_data.bin files have a certain size and byte structure
    if (validateNvDataFile(nvDataFile)) {
        writefln("Filename:    %s", filename);
        return nvDataFile;
    } else {
        stderr.writefln("Error while reading your unlock code.");
        stderr.writefln("Is this a valid or corrupt %s file?", NV_DATA_PATH);
        return null;
    }
}


/**
 * Performs validation of an nv_data.bin file. It checks for a minimum size and for a specific byte
 * pattern at certain offsets.
 *
 * Parameters:
 *     nvDataBytes  The nv_data.bin file to validate
 * Returns:
 *     true if the file is valid, false otherwise.
 */
bool validateNvDataFile(ubyte[] nvDataBytes) {

    // Make sure that the file size is greater than the offset we'll look at
    if (nvDataBytes.length < CODE_LOCATION + CODE_LENGTH) {
        return false;
    }

    // The preceding byte is always 0xFF
    if (nvDataBytes[CODE_LOCATION - 1] != FIRST_BYTE) {
        return false;
    }

    string unlockCode = getUnlockCode(nvDataBytes);
    char[] characters = cast(char[]) unlockCode;

    // Make sure unlockCode only contains valid ASCII characters between '0' and '9' inclusive
    foreach(character; characters){
        if (character < ASCII_0 || character > ASCII_9) {
            return false;
        }
    }

    return true;
}

/**
 * Gets the carrier unlock code from the nva_data.bin file.
 *
 * Parameters:
 *     nvDataBytes  The nv_data.bin file to get the unlock code from.
 * Returns:
 *     A string containing the carrier unlock code.
 */
string getUnlockCode(ubyte[] nvDataBytes) {
    int startOffset = CODE_OFFSET;
    int endOffset = CODE_OFFSET + CODE_LENGTH;
    char[] unlockCode = cast(char[]) nvDataBytes[startOffset..endOffset];

    if (DEBUG) {
        writefln("Code:   %s", unlockCode);
        writefln("Length: %d", unlockCode.length);
    }

    return cast(string) unlockCode;
}

/**
 * Prints the carrier unlock code to stdout.
 *
 * Parameters:
 *     nvDataBytes  The nv_data.bin file to get the unlock code from.
 */
void printUnlockCode(ubyte[] nvDataBytes) {
    writefln("Unlock Code: %s", getUnlockCode(nvDataBytes));
}

/**
 * Gets the current carrier lock status from the nv_data.bin file. This can be one of the following:
 *
 *     0x0 (Unlocked) or 0x1 (Locked)
 *
 * Any other value will be treated as unknown. If a non 0x0 or 0x1 value is found, it is very likely
 * that the nv_data.bin file is invalid or corrupt.
 *
 * Parameters:
 *     nvDataBytes  The nv_data.bin file to get the unlock code from.
 * Returns:
 *     The current lock status value of the file.
 */
ubyte getLockStatus(ubyte[] nvDataBytes) {
    return nvDataBytes[LOCK_OFFSET];
}

/**
 * Formats the lock status as one of three strings:
 *
 *      "Unlocked", "Locked" or "Unknown"
 *
 * See the description for getLockStatus() for information on which byte values correspond to each
 * status.
 *
 * Parameters:
 *     lockStatus   The current lock status value to return as a string.
 * Returns:
 *     A human readable string representation of the lock status value.
 */
string getLockStatusString(ubyte lockStatus) {
    if (lockStatus == UNLOCKED) {
        return "Unlocked";
    } else if (lockStatus == LOCKED) {
        return "Locked";
    }

    // Most likely an invalid nv_data.bin file
    return "Unknown";
}

/**
 * Prints the nv_data.bin lock status string to stdout.
 *
 * Parameters:
 *     nvDataBytes  The nv_data.bin file to get the lock status from.
 */
void printLockStatus(ubyte[] nvDataBytes) {
    writefln("Lock Status: %s", getLockStatusString(getLockStatus(nvDataBytes)));
}

/**
 * Sets the passed in lock status value to the nv_data.bin file in memory. Usually done before
 * writing the file out to the filesystem using writeFile(). The function will return false when
 * the lock status is neither UNLOCKED (0x0) nor LOCKED (0x1) since these are the only two values
 * the phone checks for to know whether nv_data.bin is carrier locked or unlocked.
 *
 * Parameters:
 *     lockStatus   The desired lock status, UNLOCKED (0x0) or LOCKED (0x1) to set.
 *     nvDataBytes  The nv_data.bin file to set the lock status for.
 * Returns:
 *     true if the file's lock status was successfully set, false otherwise.
 */
bool setLockStatus(ubyte lockStatus, ref ubyte[] nvDataBytes) {
    if (lockStatus != LOCKED && lockStatus != UNLOCKED) {
        stderr.writefln("Could not set lock status:");
        stderr.writefln("\tInvalid lock_status passed in to setLockStatus()");
        stderr.writefln("\tlockStatus can only be 0x%x or 0x%x", LOCKED, UNLOCKED);
        return false;
    }

    // Set the lock status to the passed in value
    nvDataBytes[LOCK_OFFSET] = lockStatus;
    return true;
}

/**
 * Writes the nv_data.bin file from memory to the filesystem using the passed in lock status and
 * filename.
 *
 * Parameters:
 *     lockStatus       The desired lock status, UNLOCKED (0x0) or LOCKED (0x1) to set.
 *     outputFilename   The desired filename for the output file.
 *     nvDataBytes      The nv_data.bin file to set the lock status for.
 * Returns:
 *     true if the file was successfully written, false otherwise.
 */
bool writeFile(ubyte lockStatus, string outputFilename, ubyte[] nvDataBytes) {
    // Set the requested lock status
    if (!setLockStatus(lockStatus, nvDataBytes)) {
        return false;
    }

    try {
        std.file.write(outputFilename, nvDataBytes);
    } catch (FileException e) {
        stderr.writeln("Error while writing the file");
        stderr.writeln(e.msg);
        return false;
    }

    return true;
}
