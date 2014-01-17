#!c:\strawberry\perl\bin\perl
#-------------------------------------------------------------------------------
# This scripts prepends "XML" on a new line in the GIPE XML files
#
# c:\strawberry\perl\bin\perl "C:\Performance Testing\201305_GIPE_PI_VIC_FSL\prepareGIPEXml.pl"
#
# It prepends the "XML" line to xml files in the current directory.
#
# Run it using the command above.
#-------------------------------------------------------------------------------
# 07/11/2013 v1.0 Initial version

use strict;
use Cwd;
use IO::File;

#-----------------------------------------------------------
# Make a list of XML files
#-----------------------------------------------------------
my $dir = getcwd;
my (@files) = getFiles($dir);

#-----------------------------------------------------------
# Now process each of the scripts
#-----------------------------------------------------------
my $changeCount = 0;
my $fileChanges = 0;
my $fileCount = 0;
foreach my $file (@files){
	#Make a list of c files for the script
	#-----------------------------------------------------------
	# Now process the c files within the script directory
	#-----------------------------------------------------------
	my $changes = processFile($dir, $file);
	$fileChanges++ if ($changes > 0);
	$fileCount++;
}
print "$fileCount changes\n";
exit(0);

#-----------------------------------------------------------
# Look for the c files within the script directory
#-----------------------------------------------------------
sub getFiles{
	my ($scriptDir) = @_;

	my @files;
	opendir(my $dh, $scriptDir) || die "Cannot read directory $scriptDir: $!";
	while (my $name = readdir $dh){
		if ($name =~ /\.(dat|xml)$/){
			push(@files, $name);
			print $name."\n";
		}
	}
	closedir $dh;
	return(@files);
}

#-----------------------------------------------------------
# Look for the XML files within the current directory
#-----------------------------------------------------------
sub processFile{
	my ($dir, $file) = @_;

	my $dataFile = $dir.'/'.$file;
	print "Processing $file\n";
	prepend_file($dataFile,"XML\r\n", 8096);
	return(1);
}

sub prepend_file {
  my $file        = shift;
  my $data        = shift;
  my $buffer_size = shift;

  #Open a temporary and source file handle
  my $temp_fh = IO::File->new_tmpfile
    or die "Could not open a temporary file: $!";

  my $fh= IO::File->new($file, O_RDWR)
    or die "Could not open file $file: $!";

  #Write the first bit of data
  $temp_fh->syswrite($data);

  #Copy all the $data from the $fh to the temp file handle
  $temp_fh->syswrite($data) while $fh->sysread($data, $buffer_size);

  $temp_fh->sysseek(0, 0);
  $fh->sysseek(0, 0);

  #Write out the new file from the temporary file handle
  $fh->syswrite($data) while $temp_fh->sysread($data, $buffer_size);

  #could return anything here, I just chose the file handle just
  #in case we needed to use it for something.
  return $fh->sysseek(0, 0) && $fh;
}
