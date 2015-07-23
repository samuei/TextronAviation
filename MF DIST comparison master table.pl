#!/apps/open/bin/perl

use strict;
use File::Basename;
use DBI;
use DBD::DB2;
use Data::Dumper; #Not sure this is used

$Debug = 1;
#	Set Debug=1 for debugging, Debug=0 turns it off
#
#	This script will connect to and query the distributed DB2 Master table
#	to collect a list of its ECRs and the last date of update.
#	It will connect to and query the mainframe DB2 to compare
#	those update dates to the ones on the mainframe DB2 Master table.
#
#	Lastly, it will poll both tables for their total number of entries.
#
#  - - - - - - - - -
#  SAL - 20150605 - Script created. Incomplete! Needs distributed connection data
#                           
#  - - - - - - - - -
#

# Parms format:
# [0]: application name
# [1]: user/login
# [2]: schema (DB2PP or DB2PT)
# [3]: prod or test (DSP or DST)
# [5]: db2adm

# Connect to the distributed DB (incomplete!)
print " Connect to Distributed DB\n" if ($DEBUG);
$cmd = "APP user/pass schema db2adm"; #Need connection info! This will not work as-is!
print "$cmd"  if ($DEBUG);
$iret = `$cmd`;
chomp($iret);
print " IRET= $iret" if ($DEBUG);
@Parms1 = split(/\s+/,$iret);
($userid1, $login1)=split(/\//, $Parms1[1]);
$database1 = 'DBI:DB2:' . $Parms1[3];
$tables1 = $Parms1[2];
$TABLE_NOTES1 = $Parms[2] . '.F0BDTCA';
print " DB=$databas1\n" if ($DEBUG);
print " user=$userid1\n" if ($DEBUG);
print " PW=$login1\n" if ($DEBUG);
$db_handle1=DBI->connect($database1,$userid1,$login1,{RaiseError=>1,AutoCommit=>1}) || die $DBI::errstr;

# Connect to the mainframe DB
$cmd = "APP user/pass schema db2adm"; #Need connection info! This will not work as-is!
print "$cmd"  if ($DEBUG);
$iret = `$cmd`;
chomp($iret);
print " IRET= $iret" if ($DEBUG);
@Parms2 = split(/\s+/,$iret);
($userid2, $login2)=split(/\//, $Parms2[1]);
$database2 = 'DBI:DB2:' . $Parms2[3];
$tables2 = $Parms2[2];
$TABLE_NOTES2 = $Parms2[2] . '.F0BDTCA';
print " DB=$databas2\n" if ($DEBUG);
print " user=$userid2\n" if ($DEBUG);
print " PW=$login2\n" if ($DEBUG);
$db_handle2=DBI->connect($database2,$userid2,$login2,{RaiseError=>1,AutoCommit=>1}) || die $DBI::errstr;

# Get Distributed data
$selstring=" SELECT ECR_NUMBER, ECRM_LST_UPDT_DT ";
$fromstring=" FROM $TABLE_A ";
$orderstring=" ORDER BY ECR_NUMBER USING UR ";
$SQL1 = "$selstring $fromstring $orderstring";
print "SQL1=$SQL1\n" if ($DEBUG);
$sth1=$db_handle1->prepare($SQL1);
$sth1->execute;
# Declaring variables for later
@row; $ecrno; $distdate; $mfdate; $nummisses=0;
print " ECR Date mismatches: \n";

# Compare ECRs and report mismatches
while(@row = sth1->fetchrow_array)
{
	$ecrno = $row[1]; 
	$distdate = $row[2]; 
	$SQL2 = " SELECT ECRM_LST_UPDT_DT FROM TABLE_A WHERE ECR_NUMBER=$ecrno USING UR ";
	$sth2=$db_handle2->prepare($SQL2);
	$sth2->execute;
	$sth2->bind_col(1,\$mfdate);
	$sth2->fetch;
	print " mfdate=$mfdate\n" if ($DEBUG);
	if ($mfdate != $distdate)
	{
		print " $ecrno - Distributed($distdate)  Mainframe($mfdate) \n";
		$nummisses++;
	}
}
print " Found $nummisses mismatched entries. \n";

# Compare counts
$SQL1 = " SELECT COUNT(*) FROM TABLE_A ";
$SQL2 = " SELECT COUNT(*) FROM TABLE_A ";
$sth1=$db_handle1->prepare($SQL1);
$sth2=$db_handle2->prepare($SQL2);
$sth1->execute;
$sth2->execute;
$sth1->bind_col(1,\$count1);
$sth2->bind_col(1,\$count2);
$sth1->fetch;
$sth2->fetch;
print " Count: Distributed($count1)  Mainframe($count2) ";

# Shut. Down. Everything.
$sth1->finish();
$sth2->finish();
$db_handle1->disconnect();
$db_handle2->disconnect();
