#!/usr/bin/perl

###################################################################################
#   eZmount -- A utility for cleanly and conveniently mounting disk images
#   Authors :: Clint Edwards, Christopher Vuotto, and Josh McSavaney
###################################################################################

use strict;
use warnings;
use Term::ANSIColor;

#### Essentials ####
my @mapped_partitions = ();
my $image_abs_path = "";
my $UUID = "";
my $UUID_path = "";
my $loop_dev = "^NOMATCH";
#my @input = ();
my $input = "";
my $directory = "~/eZmount";
####################


my $banner = <<'DONE';
       _____                            _
   ___|__  /_ __ ___   ___  _   _ _ __ | |_
  / _ \ / /| '_ ` _ \ / _ \| | | | '_ \| __|
 |  __// /_| | | | | | (_) | |_| | | | | |_
  \___/____|_| |_| |_|\___/ \__,_|_| |_|\__|

DONE
#The above is how a multi-line string can be easily created.

sub listVolumes
{
    if (! shift )
    {
        print "\n";
        system("parted $image_abs_path -s print | grep --color=never -e '^Number\\s' -e '^\\s[[:digit:]]\\s'");
        print "\n";
    }

    my $i = 1;
    foreach (@mapped_partitions)
    {
        print "$i -- $_ ";
        print '[Mounted]' if ( isMounted($_) );
        print "\n";
        $i ++;
    }
}

sub changeDirectory
{
    print "Where would you like for your volumes to be mounted?\ndirectory : ";
    my $temp_directory = "";
    $temp_directory = <STDIN>;
    chomp $temp_directory;
    $temp_directory = `readlink -f '$temp_directory' >/dev/null 2>/dev/null`;
    chomp $temp_directory;
    if ( system("stat '$temp_directory' >/dev/null 2>/dev/null") )
    {
        print "'$temp_directory' does not exist.\nAttempt to create it and required parent directories? [y/N] : ";
        my $choice = "";
        $choice = <STDIN>;
        if ( "yes" =~ /$choice/i )
        {
            !system( "mkdir -p '$temp_directory' 2>/dev/null >/dev/null" ) or warn "Failed to create $temp_directory\n" and return;
        }
        else {return;}
    }

    if ( !system("grep '\#.eZdir' '$UUID_path' >/dev/null 2>/dev/null") )
    {
        system( "sed -e 's/\#.eZdir\t/\#.eZdir\t$temp_directory/' $UUID_path" );
    }
    else
    {
        !system( "echo -e '\#.eZdir\t$temp_directory' >> '$UUID_path'") or die ("Failed to write to $UUID_path");
    }
    $directory = $temp_directory;
}

sub isMounted
{
    my $device = shift;
    return !system("grep \"$device\" /etc/mtab >/dev/null 2>/dev/null");
}

sub isLooped
{
    #this will NOT work with the loop-UUID form of the device.
    #you must either use the loopX the loop-UUID is hard linked to or
    #the image file path you looped
    my $device = shift;
    !system("losetup -a | grep \"$device\" >/dev/null 2>/dev/null");
}

sub cleanLoop
{
    my $device = shift;
    if ( system("kpartx -d \"$device\"") )
    {
        warn "A mapped partition of $device appears to be in use. Make sure the mapped partitions are unmounted and try again.\n";
        return;
    }
    if ( system("losetup -d \"$device\"") )
    {
        warn "$device cannot be unlooped because it is still in use. Make sure it is not in use by any other process.\n";
        warn "In some scenarios, a kernel patch may be required. For an explanation, see: http://lxr.linux.no/linux+v3.9/drivers/block/loop.c#L998\n";
    }
}

sub init
{
    my $image_path = shift; #grab the relative path of our image
    chomp $image_path;

    #determine the absolute path of our image
    $image_abs_path = `readlink -f "$image_path" 2>/dev/null`;
    chomp $image_abs_path;
    die "$image_path does not exist" if system("stat \"$image_abs_path\" >/dev/null 2>/dev/null");

    #parse out the path and actual name of the image
    my ($image_location, $image_name) = ($image_abs_path =~ m/^(\/.*[^\\]\/)(.*)/);

    #generate the proper path for our UUID file
    $UUID_path = "${image_location}.eZmount-uuid";

    #attempt to parse the UUID from our file. If we fail, no big deal.
    $UUID = `grep "$image_name" "$UUID_path" 2>/dev/null | cut -f2`;

    #if the image isn't in the UUID file or if the UUID file doesn't exist, make it so.
    $UUID = `echo -en "$image_name\t" >> "$UUID_path"; uuidgen | tee -a "$UUID_path"` if ( $UUID eq "" );
    chomp $UUID;

    $loop_dev = "/dev/loop-$UUID";

    #see if our loop device exists anywhere. If it doesn't, make it so. If it does, do nothing.
    !system ("losetup \"$loop_dev\" 2>/dev/null | grep \"($image_abs_path)\" >/dev/null ") or \
        !system("ln -f `losetup --show -f -r $image_abs_path` \"$loop_dev\"") or die "Failed to setup loopback";

    #determine our map points and then map our partitions to /dev/mapper
    @mapped_partitions = map( "/dev/mapper/$_", `kpartx -l "$loop_dev" | cut -d" " -f1`);
    chomp(@mapped_partitions);
    die "Failed to predict mappings" if ($#mapped_partitions == 0);
    system("kpartx -a \"$loop_dev\" 2>/dev/null");
    #it is faster to call kpartx and have it do nothing than to check ahead of time
    my $temp_dir = $directory;
    $directory = `grep '^\#.eZdir\\s' '$UUID_path' | cut -f2 2>/dev/null`;
    if ($directory eq ""){
        $directory = $temp_dir;
        !system("echo -e '\#.eZdir\t$directory' >>'$UUID_path' 2>/dev/null") or die "Couldn't write mount dir to $UUID_path";
    }

    1; #ensure this function returns a value equating to true by having it's last statement evalute to something true
}


sub welcome {

    print "\n";
    print "Welcome to eZmount!\n";
    print "\n";

}

sub printHelp {
    print ("\n");
    print ("help    -- display this message\n");
    print ("list    -- list available volumes\n");
    print ("dir     -- change mount directory\n");
    print ("mount   -- mount a partition from your image\n");
    print ("unmount -- unmount a mounted partition\n");
    print ("quit    -- exit eZmount\n");
    print ("\n");
}

sub printMountOptions{
    print ("\n");
    print ("h --help\n");
    print ("l --list\n");
    print ("s --mount single volume\n");
    print ("a --mount all volumes\n");
    print ("q --quit\n");
    print ("\n");
}

sub printUnmountOptions{
    print ("\n");
    print ("h --help\n");
    print ("l --list\n");
    print ("s --unmount single volume\n");
    print ("a --unmount all volumes\n");
    print ("q --quit\n");
    print ("\n");
}

sub mountSingle {

    print "Available volumes:\n";
    listVolumes(1);
    print "Volume number: ";
    my $choice = <STDIN>;
    chomp $choice;
    if ($choice =~ /^[[:digit:]]+$/ and $choice < ($#mapped_partitions + 1) and !isMounted($mapped_partitions[$choice-1]))
    {
        system("mkdir -p '$directory/$UUID/$choice' >/dev/null 2>/dev/null");
        system("mount -o ro,noexec '$mapped_partitions[$choice-1]' '$directory/$UUID/$choice' >/dev/null 2>/dev/null");
        print "Volume mounted properly at $directory/$UUID/$choice\n";
    }
    else
    {
        warn "Invalid choice. The device may either already be mounted or you specified an invalid volume.\n";

    }
}

sub mountAll {

    print "\n";
    print "Are you sure you want to mount all volumes? [y/n]";
    my $i = <STDIN>;
    chomp $i;

    if ("yes" =~ /^$i/i){
        print "\n";
        print "This should iterate through all the mount points and run the mount command on them.";
    }
    else{
         print "\n";
        print "Returning to mount menu";
    }
}

sub unmountSingle {

    print "\n";
    print "Which volume would you like to unmount? ";
    my $i = <STDIN>;
    chomp $i;
    #print the list of volumes it is possible to unmount here.
    #like so:
    # 1 - /mnt
    # 2 - /blah
    # 3 - /blah3

    if($i =~ /^[[:digit:]]+$/){
    #print("umount " . $mapped_partitions[$i-1]); #test print statement
    system("umount " . $mapped_partitions[$i-1]) and die "Failed to unmount volume";
    #System calls return a 0 on success, which evaluates to False

    print "Successfully unmounted";
    #Make sure we delete the directory that it was mount to afterwards.
    }else{
        print "Returning to unmount menu";
    }
}

sub unmountAll {
    print "\n";
    print "Are you sure you want to unmount all volumes? [y/n]";
    my $i = <>;
    chomp $i;

    if ("yes" =~ /^$i/){
        foreach (@mapped_partitions)
        {
            system("umount $_ >/dev/null 2>/dev/null");
        }
        print "If it could be unmounted, it was unmounted.\n";
    }
    else{
        print "\n";
        print "Returning to unmount menu";
    }
}

sub unmountMenu {

    my $unmountloopend = 0;
    my $unmountinput;

    printUnmountOptions();

    while($unmountloopend != 1){
       print "\n";
       print "unmount command : ";
       $unmountinput = <STDIN>;
       chomp $unmountinput;

       if ("single" =~ /^$unmountinput/){
           unmountSingle();
           $unmountloopend = 1;
       }
       elsif ("all" =~ /^$unmountinput/){
           unmountAll();
           $unmountloopend = 1;
       }
       elsif ("list" =~ /^$unmountinput/){
           listVolumes();
       }
       elsif ("help" =~ /^$unmountinput/){
           printUnmountOptions();
       }
       elsif ("quit" =~ /^$unmountinput/){
       $unmountloopend = 1;
       }else{
           print "Not a valid command, please try again";
       }
   }
}

sub mountMenu {

    my $mountloopend = 0;
    my $mountinput;

    printMountOptions();

    while($mountloopend != 1){
        print "\n";
        print "mount command : ";

        $mountinput = <STDIN>;
        chomp $mountinput;

        if ("single" =~ /^$mountinput/){
            mountSingle();
            $mountloopend = 1;
        }
        elsif ("all" =~ /^$mountinput/){
            mountAll();
            $mountloopend = 1;
        }
        elsif ("list" =~ /^$mountinput/){
            listVolumes();
        }
        elsif ("help" =~ /^$mountinput/){
            printMountOptions();
        }
        elsif ("quit" =~ /^$mountinput/){
            $mountloopend = 1;
        }else{
            print "Not a valid command, please try again";
        }
    }
}

sub main {

    my $loopend = 0;

    print color('green'), $banner, color('reset');
    welcome();
    $_ = shift;
    die "Usage: eZmount disk_image\n" if !$_;
    init($_);
    #@input = @_;
    printHelp();

    while($loopend != 1){
        print "\n";
        print "command : ";

        #@input = split( /\s/ <STDIN>;
        $input = <STDIN>;
        chomp $input;

        if ("mount" =~ /^$input/){
            mountMenu();
        }
        elsif ("list" =~ /^$input/){
            listVolumes();
        }
        elsif ("unmount" =~ /^$input/){
            unmountMenu();
        }
        elsif ("quit" =~ /^$input/){
            $loopend = 1;
        }
        elsif ("help" =~ /^$input/){
            printHelp();
        }
        elsif ("directory" =~ /^$input/){
            changeDirectory();
        }
        else{
            print "Not a valid command, please try again";
        }
    }
}

my $id = `id -u`;
chomp $id;
warn  color("red"), "\n";
warn "This program was designed to be run with root access. All bets are off.\n" if ( '0' ne $id ) ;

main(shift);