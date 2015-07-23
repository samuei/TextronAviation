#! /bin/ksh
set -
#   -x turns on debugging, - turns it off
#
#   This script isolates files in the current directory whose name
#	contains a specified string, and deletes any of them that has a 
#	second string in its ls -l data.
#
#	It looks like \ may be necessary before regexes.
#	Shouldn't delete from subdirectories, but I make no promises.
#
#	****************************************************************
#		  WARNING: THIS SCRIPT DELETES DATA WITHOUT PROMPTING!
#	If you pass *, all or part of the first parameter, or a standard
#	part of the ls -l return format as the second parameter, it will
#	delete ALL files that match the first parameter. If that 
#	parameter is \*, all files in the current folder will be deleted.
#		Don't be stupid. Don't use this script in stupid ways.
#						  Delete responsibly.
#	****************************************************************
#
#   to run this from the command line:
#          parameter $(0)   full path name (supplied automatically)
#          parameter $(1)   filename string (ex: dwg, .exe, \*)
#		   parameter $(2)	deletion string (ex: 2014, appqa, Nickleback)
#
# ./seekAndDestroy.ksh .exe totallynotavirus
#
#  - - - - - - - - -
#  SAL - 2015-06-19 - Testing. Really hoping this doesn't burn down anything 
#					  important
#  SAL - 2015-06-18 - Created script
#                           
#  - - - - - - - - -

if [ ${#} -ne 2 ]
then
	echo "Syntax: ./seekAndDestroy.ksh filenamestring deletionstring"
	echo "No, seriously, though. This script's dangerous. Don't screw around."
	exit
fi

for file in *${1}*
do
	if [[ ${file} = seekAndDestroy.ksh ]]
	then
		echo "Not removing this script. You need to rethink your queries."
		continue
	elif [[ ${file} = *${1}* ]]
	then
		if [[ `ls -l ${file} | grep ${2}` = *${2}* ]]
		then
			echo "Removing ${file}"
			rm -f ${file}
		fi
	fi
done
