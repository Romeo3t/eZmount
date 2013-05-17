           _____                            _
       ___|__  /_ __ ___   ___  _   _ _ __ | |_
      / _ \ / /| '_ ` _ \ / _ \| | | | '_ \| __|
     |  __// /_| | | | | | (_) | |_| | | | | |_
      \___/____|_| |_| |_|\___/ \__,_|_| |_|\__|


##by Josh McSavaney, Clint Edwards, and Christopher Vuotto
##May 3rd, 2013
##Last update: May 17th, 2013











#Executive Summary

In our short lives we only have the time to do one, maybe two important things that the world will remember us by when our time has passed. For a team of three who only truly worked on this for about two weeks, eZmount is our gift to this world.
Many a time, forensic investigators, system administrators and just tech junkies in general have gone through the trouble of obtaining an image and mounting different parts of the image depending on what needs to be done. For those not adept at the process it takes to mount an image that might have a million or more different partitions/volumes. This process could take you the better part of the day.
That is why we created the eZmount tool. In the span of a simple perl script we have created a tool that will take your image file, display the possible mountable portions of it and then help you mount all of those portions or just specific ones that you may be fond of. In upcoming patch updates, the eZmount will also be able to mow your lawn and take the dog out too!






#Current Condition Overview

Currently it doesn't blow up the computer that it is being run on. Which is an improvement from recent versions.

Ezmount is in full working condition, although it will need a further array of testing from different operating systems and image types.

Usability: The program needs to be run with root access.

Usability: Tested on CentOs 6.2, Linux kernel  v. 2.6.32 With fully up to date system.

Feature: Forensics mode off/on – Is a feature we are thinking about for the future.

Feature: Make user breakfast – Is going to require more of an investment($5,000) than we initially put 			in ($0)






#Tool Selection

We used many tools to accomplish the greatness that is eZmount

* kpartx - http://linux.die.net/man/8/kpartx
* mount - http://linux.die.net/man/8/mount
* umount - http://linux.die.net/man/8/umount
* parted - http://linux.die.net/man/8/parted
* losetup - http://linux.die.net/man/8/losetup







#Tool development
1. After deciding the most important features for our tool
2. We separated the tool based on the various functions that needed to be created and each took a piece and tried to conquer it.
3. In the final hours, we pushed our functions together and prayed to the code gods that they worked. (The code gods mostly consisted of Josh who fixed all the “code incompatibility” errors we experienced)





#Issues

The main issues we encountered were of the nature of limitations in the tools we used to make eZmount work and the issue of maintaining usability for the end user.

Usability was always a goal in creating eZmount, so throughout the program we had to always make a conscious decision on what would make the user's life easy. Making the user's life easy usually results in more code.
Figuring out a good way to separate and conquer the coding portion of the project was a problem we all had to deal with. As we all have different level of coding experience it was tough figuring out who would be apt to do which portions.

The other work from various other classes made this difficult to provide the full energy we wanted to.






#Conclusion
When we started this project it was more than just a forensics class final. We actually hoped to make a tool that people would actually use and most importantly would help us with our future endeavors in the forensics world. In conclusion, I think we accomplished our goals and made something we are all proud of.




References

The Perl documentation, some portions of the Linux kernel's source code, and the man pages for scalpel after an attempt to remove /~/~ recursively failed catastrophically.

