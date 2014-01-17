#!c:\strawberry\perl\bin\perl
#-------------------------------------------------------------------------------
# This scripts deletes log and temp files and folders and then zips ready for
# upload.
#
# c:\strawberry\perl\bin\perl "C:\Performance Testing\201305_GIPE_PI_VIC_FSL\cleanAndZip.pl"
#
# Run it using the command above.
#-------------------------------------------------------------------------------
# 08/11/2013 v1.0 Initial version
# 15/11/2013 v1.1 Disable logging and set iteration count to 1
# 06/01/2014 v1.2 Remove all TXT and LOG files
# 07/01/2014 v1.3 Special case for LSP

use strict;
use Getopt::Long;
use Cwd;
use IO::File;
use File::Path qw(make_path remove_tree);
use File::stat;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Config::Tiny;

my $debug = 1;
my $lspFlag = 0;

#-----------------------------------------------------------
# Use the current directory
#-----------------------------------------------------------
my $startDir = getcwd;
my $dir = $startDir;
my @components = split('/',$dir);

#-----------------------------------------------------------
# Validate the directory
#-----------------------------------------------------------
die "\"$dir\" is not a Performance Testing directory\n" if ($components[1] ne 'Performance Testing');
die "\"$dir\" is not a specific Performance Test directory\n" if (scalar(@components) < 3);

#-----------------------------------------------------------
# LSP Directory structure is deeper
#-----------------------------------------------------------
#c:/Performance Testing/LSP_Master_Project/Master_Scripts/#SendToALM
$lspFlag = 1 if ($components[2] eq 'LSP_Master_Project');

if (scalar(@components) > 3  && !$lspFlag){
	die "\"$dir\" is not the Scripts Test directory\n" if ($components[3] ne 'Scripts');
}

if (scalar(@components) < 4){
	$dir = "$startDir/Scripts";
	print "New directory $dir\n";
} else {
	print "Directory $dir\n";
}

open LOG, "> $dir\\cleanAndZip.log" if ($debug);
message("===============================================================================\n", $debug);

#-----------------------------------------------------------
# Make a list of Scripts
#-----------------------------------------------------------
my ($scriptDir,@scripts) = getScripts($dir);

#-----------------------------------------------------------
# Now process each of the scripts
#-----------------------------------------------------------
foreach my $script (@scripts){
	#---------------------------------------------------------
	# Remove unnecessary files and directories
	#---------------------------------------------------------
	cleanScript($dir, $script);

	#---------------------------------------------------------
	# See if he Zip files need updating
	#---------------------------------------------------------
	if (updateRequired($dir, $script)){
		print "Create or update ZIP Required\n";

		# Zip the script
		zipScript($dir, $script);
	}

	message("---------------------------------------------------------------------------\n", $debug);
}
close LOG;
exit(0);

#-----------------------------------------------------------
# Make a list of Scripts based on
#-----------------------------------------------------------
sub getScripts{
	my ($dir) = @_;

	my @components = split('/',$dir);
	my $scriptDir;
	my @scripts;

	if ((scalar(@components) >= 5) && !$lspFlag){
		#We are in a specific script directory
		$scriptDir = $components[0].'/'.$components[1].'/'.$components[2].'/'.$components[3].'/'.$components[4].'/';
		print "Working in directory $scriptDir\n";
		push(@scripts, $components[4]);
	} else {
		#Read the directory for the list of scripts
		if ($lspFlag){
			$scriptDir = $components[0].'/'.$components[1].'/'.$components[2].'/'.$components[3].'/'.$components[4].'/';
		} else {
			$scriptDir = $components[0].'/'.$components[1].'/'.$components[2].'/'.$components[3].'/';
		}
		print "Working in directory $scriptDir\n";
		opendir(my $dh, $scriptDir) || die "Cannot read directory $scriptDir: $!";
		while (my $name = readdir $dh) {
			next if ($name =~ /^\.\.?/);
			next if ($name =~ /\@Archive/i);
			next if ($name =~ /as_?recorded/i);
			next if ($name =~ /^temp/i);
			next if ($name =~ /\.zip/i);
			if (-d $scriptDir.$name){
				push(@scripts, $name);
				#print $name."\n";
			}
		}
		closedir $dh;
	}
	return($scriptDir, @scripts);
}


#-----------------------------------------------------------
# Clean up the files for the script
#-----------------------------------------------------------
sub cleanScript{
	my ($dir, $script) = @_;

	my $config = Config::Tiny->new;
	#---------------------------------------------------------
	# Remove unnecessary files and directories
	#---------------------------------------------------------
	my $scriptDir = "$dir/$script";
	message("Working on Script $script...\n", $debug);
	message("Working in directory $scriptDir\n", $debug);
	opendir(my $dh, $scriptDir) || die "Cannot read directory $scriptDir: $!";
	while (my $name = readdir $dh) {
		next if ($name =~ /^\.\.?/);
		if ($name =~ /\.(bak|idx|txt|log)$/i){
			unlink $scriptDir.'/'.$name or warn "Could not unlink $name: $!";
			message("$name Deleted\n", $debug);
		}
		#if ($name =~ /\.idx$/){
		#	unlink $scriptDir.'/'.$name or warn "Could not unlink $name: $!";
		#	message("$name Deleted\n", $debug);
		#}
		#if ($name =~ /output\.txt$/){
		#	unlink $scriptDir.'/'.$name or warn "Could not unlink $name: $!";
		#	message("$name Deleted\n", $debug);
		#}
		#if ($name =~ /(logfile|mdrv)\.log$/){
		#	unlink $scriptDir.'/'.$name or warn "Could not unlink $name: $!";
		#	message("$name Deleted\n", $debug);
		#}

		#Turn off logging, set iteration count to 1
		if ($name eq 'default.cfg'){
			$config = Config::Tiny->read( "$scriptDir/$name" );
			#NumOfIterations=1
			#LogOptions=LogDisabled
			my $changeCount = 0;
			my $logOptions = $config->{'Log'}->{'LogOptions'};
			if ($logOptions ne 'LogDisabled'){
				message("### Logging not Disabled, $logOptions\n", $debug);
				$config->{'Log'}->{'LogOptions'} = 'LogDisabled';
				message("### Logging Disabled\n", $debug);
				$changeCount++;
			}
			my $numIterations = $config->{'Iterations'}->{'NumOfIterations'};
			if ($numIterations != 1){
				message("### Iteration Count not set to 1, $numIterations\n", $debug);
				$config->{'Iterations'}->{'NumOfIterations'} = 1;
				message("Iteration Count set to 1\n", $debug);
				$changeCount++;
			}
			if ($config->{'WEB'}->{'ProxyUseProxy'}  && ($config->{'WEB'}->{'ProxyPassword'} ne 'catap0ha')){
				message("################################################\n", $debug);
				message("### Proxy Password is wrong!!!!\n", $debug);
				message("################################################\n", $debug);
			}

			if ($changeCount > 0){
				$config->write( "$scriptDir/$name" );
				message("Updated $scriptDir/$name\n", $debug);
			}
		}
	}
	closedir $dh;

	# Try to remove these directories
	foreach my $d ('result1','data','DfeConfig'){
		my $dir = "$dir/$script/$d";
		if (-d $dir){
			message("Deleting $dir...\n", $debug);
			remove_tree($dir);
		}
	}
}

#-----------------------------------------------------------
# Clean up the files for the script
#-----------------------------------------------------------
sub updateRequired{
	my ($dir, $script) = @_;

	#---------------------------------------------------------
	# Get the time of most recently updated file
	#---------------------------------------------------------
	my $scriptDir = "$dir/$script";
	my $lastUpdate = 0;
	opendir(my $dh, $scriptDir) || die "Cannot read directory $scriptDir: $!";
	while (my $name = readdir $dh) {
		next if ($name =~ /^\.\.?$/);
		my $f = "$dir/$script/$name";
		my $stat = stat($f);
		if ($stat->mtime > $lastUpdate){
			$lastUpdate = $stat->mtime;
			my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($stat->mtime);
			$mon++;
			$year += 1900;
			my $dateString = sprintf("%04d-%02d-%02d %02d:%02d", $year,$mon,$mday,$hour,$min);
			message("$name last updated $dateString\n", $debug);
		}
	}
	closedir $dh;

	#---------------------------------------------------------
	# Now compare to the zipped script
	#---------------------------------------------------------
	if (-f "$dir/$script.zip"){
		my $f = "$dir/$script.zip";
		my $stat = stat($f);
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($stat->mtime);
		$mon++;
		$year += 1900;
		my $dateString = sprintf("%04d-%02d-%02d %02d:%02d", $year,$mon,$mday,$hour,$min);
		message("$script Zip file last updated $dateString\n", $debug);
		if ($stat->mtime < $lastUpdate){
			return(1);
		}
	} else {
		return(1);
	}
	return(0);
}

#-----------------------------------------------------------
# Zip the script
#-----------------------------------------------------------
sub zipScript{
	my ($dir, $script) = @_;

	#---------------------------------------------------------
	# Delete the old zipped script?
	#---------------------------------------------------------
	#if (-f "$dir/$script.zip"){
	#	#unlink "$dir/$script.zip" or warn "Could not unlink $dir/$script.zip: $!";
	#	message("$dir/$script.zip Deleted\n", $debug);
	#}

	#---------------------------------------------------------
	# Get the time of most recently updated file
	#---------------------------------------------------------
	my $zip = Archive::Zip->new();
	$zip->addTree( "$dir/$script", "$script/" );
	unless ( $zip->overwriteAs({filename => "$dir/$script.zip"}) == AZ_OK ) {
		message("Error writing to $script.zip: $!\n", $debug);
		die 'write error';
	} else {
		message("### $script.zip Added/updated\n", $debug);
	}
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

#-------------------------------------------------------------------------------
# Command line options processing
#-------------------------------------------------------------------------------
sub usage{

my $usage = <<_END_OF_TEXT_;

This script sends an alert via email or to FireScope as required.

usage: $0 [-help] | {-situation sitname} {-application AppName} [-transaction TranName]
                    {-status {Y|N}} {-start StartTime} [-time time]
                    [-workstation wsname]
                    [-firescope]

 -help          : display this text
 -application   : ITM RRT Application
 -transaction   : ITM RRT Transaction
 -status        : ITM RRT Situation Status (Y or N)
 -severity      : Alert severity
 -start         : ITM RRT Start Time
 -time          : ITM RRT Average Response Time
 -workstation   : Workstation name
 -situation     : The ITM situation name
 -firescope     : Do you want to send a trap to FireScope

examples:

$0
$0 -sit RRT_PI_Archive_Availability -app "PI_Archive" -tran Login -status Y
   -start '2012-05-27 09:01' -firescope

The command line options can be shortened to unique values.
eg. -application can be shortened to -app or -a

_END_OF_TEXT_

    print STDERR $usage;
    exit;
}

