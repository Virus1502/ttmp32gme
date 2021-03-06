#!/usr/bin/env perl

# Building with pp does NOT WORK with perl v5.10.0
#  v5.10.0 will produce strange behavior in PAR applications
#  Use Perl v5.10.1 and above only.

use File::Copy::Recursive qw(dircopy);
use Path::Class;
use Cwd;

use Data::Dumper;

my $filesToAdd = "";

my $copyTo = dir( cwd, 'build', 'current' );
$copyTo->mkpath();
my $copyFrom = dir(cwd);

print "Copying source files into build/current\n\n";

my $assetsList    = "";
my $templatesList = "";
$filesToAdd .= " -a assets.list -a templates.list";

my $src_dir = dir('src');
$src_dir->recurse(
	callback => sub {
		my ($source) = @_;
		my @components = $source->components();
		shift @components;
		if ( -d $source ) {
			( dir( $copyTo, @components ) )->mkpath();
		} elsif ( -f $source && $source->basename() !~ /^\./ ) {
			my $file = file(@components);
			$source->copy_to( file( $copyTo, $file ) );
			$file = $file->as_foreign('Unix');
			print $file. "\n";
			$filesToAdd .= " -a " . qq($file);
			if ( $file =~ /^assets/ ) {
				$assetsList .= "$file\n";
			} elsif ( $file =~ /^templates/ ) {
				$templatesList .= "$file\n";
			}
		}
	}
);

( file( $copyTo, 'assets.list' ) )->spew($assetsList);

( file( $copyTo, 'templates.list' ) )->spew($templatesList);

my $lib_dir = dir($copyTo, 'lib');
$lib_dir->mkpath();
	
if ( $^O =~ /MSWin/ ) {
	use Win32::Exe;
	print "\nWindows build.\n\n";

	( file( 'build', 'win', 'ttmp32gme.ico' ) )
		->copy_to( file( $copyTo, 'ttmp32gme.ico' ) );
		
	(dir('lib','win'))->recurse(
		callback => sub {
			my ($source) = @_;
			my $name = $source->basename();
			if (-f $source && $name !~ /^\./ ) {
				$source->copy_to( file( $lib_dir, $name ) );
				print 'lib/' . $name . "\n";
				$filesToAdd .= " -a " . qq(lib/$name);
			}
		}
	);

	chdir($copyTo);
	
	my $addDlls = '-l libxml2-2__.dll -l libiconv-2__.dll -l zlib1__.dll -l liblzma-5__.dll';
	
	my $result = `pp -M Win32API::File -c $addDlls $filesToAdd -o ttmp32gme.exe ttmp32gme.pl`;

# newer versions of pp don't support the --icon option any more, use Win32::Exe to manually replace the icon:
#	$exe = Win32::Exe->new('ttmp32gme.exe');
#	$exe->set_single_group_icon('ttmp32gme.ico');
#	$exe->write;

	print $result;
	if ( $? != 0 ) { die "Build failed.\n"; }

	chdir('..\..');
	my $distdir = dir('dist');
	$distdir->mkpath();

	( file( $copyTo, 'ttmp32gme.exe' ) )
		->copy_to( file( $distdir, 'ttmp32gme.exe' ) );
	`explorer dist`;
	print "Build successful.\n";

} elsif ( $^O eq 'darwin' ) {
	print "\nMac OS X build.\n\n";

	(dir('lib','mac'))->recurse(
		callback => sub {
			my ($source) = @_;
			my $name = $source->basename();
			if (-f $source && $name !~ /^\./ ) {
				$source->copy_to( file( $lib_dir, $name ) );
				print 'lib/' . $name . "\n";
				$filesToAdd .= ' -a ' . 'lib/' . $name;
			}
		}
	);

	chdir($copyTo);

	my $result = `pp -c $filesToAdd -o mp32gme ttmp32gme.pl`;

	print $result;
	if ( $? != 0 ) { die "Build failed.\n"; }

	chdir('../..');
	my $distdir = dir('dist');
	$distdir->mkpath();
	my $app_dir = dir( $distdir, 'ttmp32gme.app' );
	dircopy( ( dir( 'build', 'mac', 'ttmp32gme.app' ) )->stringify,
		($app_dir)->stringify );
	( file( $copyTo, 'mp32gme' ) )
		->copy_to( file( $app_dir, 'Contents', 'Resources', 'ttmp32gme' ) );
	`open dist`;
	print "Build successful.\n";
} else {
	print
"Unsupported platform.  Try installing the required perl modules and running the script out of the src folder.\n"
		. "Maybe even send in a patch with a build script for your platform.\n";
}

print "Cleaning build folders.\n";
$copyTo->rmtree();

print "Done.\n";
exit(0);

