#!c:\strawberry\perl\bin\perl
#-------------------------------------------------------------------------------
# This scripts reads the LSP logs after a Shakedown.
#
# c:\strawberry\perl\bin\perl lspLogs.pl
#
# Run it using the command above.
#-------------------------------------------------------------------------------
# 16/01/2014 v1.0 Initial version

use strict;
use Cwd;

my $debug = 1;
my $lspFlag = 0;

#-----------------------------------------------------------
# Use the current directory
#-----------------------------------------------------------
my $startDir = getcwd;

open LOG, "> lspLogs.log" if ($debug);
message("===============================================================================\n", $debug);

open QUOTE, "> #Quotes.csv";
print QUOTE "Script,Quote\r\n";

open COMBINED, "> #Combined.log";

#-----------------------------------------------------------
# Make a list of Logs
#-----------------------------------------------------------
my @logs;
my (@logs) = getLogs($startDir);

#-----------------------------------------------------------
# Now process each of the scripts
#-----------------------------------------------------------
message("-------------------------------------------------------------------------------\n", $debug);
foreach my $log (@logs){
	open LOGFILE, "< $log";
	print COMBINED "##################### $log #####################################\r\n";
	foreach my $line (<LOGFILE>){
		print COMBINED $line;
		#NewBusiness.c(114): QteMsg , 16400_AAMI_P_M_COM_Qte_NB , QuoteNo = CVN020059617	[MsgId: MMSG-17999]
		if ($line =~ /QteMsg , ([A-Za-z0-9_]*) , QuoteNo = ([A-Za-z0-9]*)\s/){
			print "$1,$2\n";
			print QUOTE "$1,$2\r\n";
		}
	}
	close LOGFILE;
}
close LOG;
close QUOTE;
close COMBINED;

exit(0);

#-----------------------------------------------------------
# Make a list of Scripts based on
#-----------------------------------------------------------
sub getLogs{
	my @logs;

	my ($dir) = @_;

	print "Working in directory $dir\n";
	opendir(my $dh, $dir) || die "Cannot read directory $dir: $!";
	while (my $name = readdir $dh) {
		next if ($name =~ /^\.\.?/);
		next if ($name =~ /^#/);
		next if ($name =~ /lspLogs.log/);
		if ($name =~ /\.log$/i){
			push(@logs, $name);
			print $name."\n";
		}
	}
	closedir $dh;
	return(@logs);
}



#---------------------------------------------------------------------
# Run an external command and capture the exit code and output
#---------------------------------------------------------------------
sub cmd{

	my ($cmd) = @_;

	my @output;
	my @output = `$cmd 2>&1`;
	my $code = $? >> 8;

	if ($code){
		print LOG "--------------------------------------------------------------------------\n";
		print LOG "$cmd\n";
		foreach my $line (@output){
			print $line;
			print LOG $line;
		}
		print LOG "--------------------------------------------------------------------------\n";
	}
	return($code, @output);
}

#-------------------------------------------------------------------------------
# Display a console message
# Write it to log as well if debugging turned on
#-------------------------------------------------------------------------------
sub message{
	my ($message, $debug) = @_;

	#-------------------------------------------------------------------------------
	#Connect to the Database
	#-------------------------------------------------------------------------------
	print $message;
	print LOG $message if ($debug);
}

