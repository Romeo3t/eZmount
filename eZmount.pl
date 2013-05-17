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
my $directory = "/eZmount";
####################


my $banner = <<'DONE';
       _____                            _
   ___|__  /_ __ ___   ___  _   _ _ __ | |_
  / _ \ / /| '_ ` _ \ / _ \| | | | '_ \| __|
 |  __// /_| | | | | | (_) | |_| | | | | |_
  \___/____|_| |_| |_|\___/ \__,_|_| |_|\__|

DONE
#Startup banner

#Trim function for strings
sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

#Prints out current list of volumes available to be mounted.
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


#Changes mount directory for eZmount
sub changeDirectory
{
    print "Where would you like for your volumes to be mounted?\ndirectory : ";
    my $temp_directory = "";
    $temp_directory = <STDIN>;
    chomp $temp_directory;
    $temp_directory = `readlink -f '$temp_directory' 2>/dev/null`;
    chomp $temp_directory;
    if ($temp_directory eq "")
    {
        warn "Could not create directory. Try entering a more existent path\n";
        return;
    }
    if ( system("stat '$temp_directory' >/dev/null 2>/dev/null") )
    {
        print "'$temp_directory' does not exist.\nAttempt to create it? [y/N] : ";
        my $choice = "";
        $choice = <STDIN>;
        chomp $choice;
        if ( "yes" =~ /$choice/i )
        {
            !system( "mkdir '$temp_directory' 2>/dev/null >/dev/null" ) or warn "Failed to create $temp_directory\n" and return;
        }
        else {return;}
    }

    if ( !system("grep '\#.eZdir' '$UUID_path' >/dev/null 2>/dev/null") )
    {
        my $super_temp = $temp_directory;
        $super_temp =~ s/\//\\\//g;
        system( "sed -ie 's/#.eZdir\\s.*/#.eZdir\\t$super_temp/' $UUID_path > $UUID_path" );
    }
    else
    {
        !system( "echo -e '\#.eZdir\t$temp_directory' >> '$UUID_path'") or die ("Failed to write to $UUID_path");
    }
    $directory = $temp_directory;
}

#checks to see if a given volume is mounted
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
    foreach (@mapped_partitions)
    {
        system("kpartx -d $_ >/dev/null 2>/dev/null");
    }
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
  #  $directory = `grep '^\#.eZdir\\s' '$UUID_path' | cut -f2 2>/dev/null`;
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
    print ("clean   -- wipes system back to near-original state\n");
    print ("quit    -- exit eZmount\n");
    print ("\n");
}

sub printMountOptions{
    print ("\n");
    print ("h   -- help\n");
    print ("l   -- list\n");
    print ("s   -- mount single volume\n");
    print ("a   -- mount all volumes\n");
    print ("q   -- quit\n");
    print ("\n");
}

sub printUnmountOptions{
    print ("\n");
    print ("h   -- help\n");
    print ("l   -- list\n");
    print ("s   -- unmount single volume\n");
    print ("a   -- unmount all volumes\n");
    print ("q   -- quit\n");
    print ("\n");
}

#Mount a single volume
sub mountSingle {

    #List volumes so user knows what is available
    print "Available volumes:\n";
    listVolumes(1);
    print "Volume number: ";

    #Record users input, trim it, and use it to determine which partitions need to be mounted.
    my $choice = <STDIN>;
    chomp $choice;
    $choice = trim($choice);
    if ($choice =~ /^[[:digit:]]+$/ and $choice < ($#mapped_partitions + 2) and !isMounted($mapped_partitions[$choice-1]))
    {
        #Create temporary mounting directory, mount volume with read only permissions passing
        # any errors to dev/null.
        system("mkdir -p '$directory/$UUID/$choice' >/dev/null 2>/dev/null");
        system("mount -o ro,noexec '$mapped_partitions[$choice-1]' '$directory/$UUID/$choice' >/dev/null 2>/dev/null");
        print "Volume mounted properly at $directory/$UUID/$choice\n";
    }
    else
    {
        warn "Invalid choice. The device may either already be mounted or you specified an invalid volume.\n";
    }
}

#Mount all available volumes.
sub mountAll {

    #Confirm that user wants to mount all voumes then,
    # iterate through all available volumes and run read only mount on them.
    print "\n";
    print "Are you sure you want to mount all volumes? [y/n]";
    my $choice = <STDIN>;
    chomp $choice;
    my $incre = 1;

    if ("yes" =~ /^$choice/){
    foreach (@mapped_partitions)
        {
        system("mkdir -p '$directory/$UUID/$incre' >/dev/null 2>/dev/null");
        system("mount -o ro,noexec '$_' '$directory/$UUID/$incre' >/dev/null 2>/dev/null");
	$incre++;
        }
        print "If it could be mounted, it was mounted.\n";
    }
    else{
        print "\n";
        print "Returning to mount menu";
    }
}

#Unmount a single volume
sub unmountSingle {

    #List volumes so user knows what is available
    print "\n";
    print "Available volumes:\n";
    listVolumes(1);

    #Take users input, make sure its a digit, check if its mounted, then unmount it.
    print "\n";
    print "Which volume would you like to unmount? ";
    my $choice = <STDIN>;
    chomp $choice;
    $choice = trim($choice);
    if ($choice =~ /^[[:digit:]]+$/ and $choice < ($#mapped_partitions + 2) and isMounted($mapped_partitions[$choice-1]))
    {
	system("umount '$mapped_partitions[$choice-1]' >/dev/null 2>/dev/null");
        system("rm -drf '$directory/$UUID/$choice' >/dev/null 2>/dev/null");

        print "\n Volume unmounted and directory deleted properly \n";


    }else{
         warn "Invalid choice. The device may either already be unmounted or you specified an invalid volume.\n";
    }
}

#Unmount all mounted volumes
sub unmountAll {
    print "\n";
    print "Are you sure you want to unmount all volumes? [y/n]";
    my $choice = <>;
    chomp $choice;


    #Iterate through mounted partition array, unmount all.
    # Then remove temporary directories used to mount, passing all errors to null.
    if ("yes" =~ /^$choice/){
        foreach (@mapped_partitions)
        {
            system("umount $_ >/dev/null 2>/dev/null");
        }
	system("rm -drf '$directory/' >/dev/null 2>/dev/null");
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
  	$unmountinput = trim($unmountinput);


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
       elsif ("ls" =~ /^$input/){
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
        $mountinput = trim($mountinput);

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
        elsif ("ls" =~ /^$input/){
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

sub cleanDir(){
 foreach (@mapped_partitions)
   	{
            system("umount $_ >/dev/null 2>/dev/null");
        }
	system("rm -drf '$directory/' >/dev/null 2>/dev/null");
        print "If it could be unmounted, it was unmounted.\n";

        print "\n";
        print "Cleaning complete";

}

sub main {

    my $loopend = 0;

    #Print banner and welcome messages
    print color('green'), $banner, color('reset');
    welcome();


    $_ = shift;
    die "Usage: eZmount disk_image\n" if !$_;
    init($_);
    #@input = @_;
    printHelp();

    #Main while statement for UI
    while($loopend != 1){
        print "\n";
        print "command : ";

        #@input = split( /\s/ <STDIN>;
        $input = <STDIN>;
        chomp $input;
        $input = trim($input);

        if ("mount" =~ /^$input/){
            mountMenu();
        }
        elsif ("list" =~ /^$input/){
            listVolumes();
        }
        elsif ("ls" =~ /^$input/){
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
        elsif ("clean" =~ /^$input/){
            my $device_path = "";
            $device_path = <STDIN>;
            chomp $device_path;
            cleanLoop($device_path);
            cleanDir();
	    }
        else{
            print "Not a valid command, please try again";
        }
    }
}

#if uid of current user is not root, print error message.
my $id = `id -u`;
chomp $id;
warn  color("red"), "\n";
warn "This program was designed to be run with root access. All bets are off.\n" if ( '0' ne $id ) ;

main(shift);


