# autolatex - Map.pm
# Copyright (C) 2013  Stephane Galland <galland@arakhne.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; see the file COPYING.  If not, write to
# the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

=pod

=head1 NAME

Make.pm - Make-like Tools

=head1 DESCRIPTION

Provides tools that are close to the Make tool.

To use this library, type C<use AutoLaTeX::Make::Make;>.

=head1 GETTING STARTED

=head2 Initialization

To create a Make tool, say something like this:

    use AutoLaTeX::Make::Make;

    my $make = AutoLaTeX::Make::Make->new($configuration) ;

...or something similar. Acceptable parameters to the constructor are:

=over

=item * C<configuration> is an associative array that contains all the configuration of AutoLaTeX.

=back

=head1 METHOD DESCRIPTIONS

This section contains only the methods in TeXParser.pm itself.

=over

=cut
package AutoLaTeX::Make::Make;
require 5.004;

our @ISA = qw( Exporter );
our @EXPORT = qw( );
our @EXPORT_OK = qw();

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
use Exporter;
use Class::Struct;
use File::Basename;
use File::Spec;
use Carp;

use AutoLaTeX::Core::Util;
use AutoLaTeX::Core::Locale;
use AutoLaTeX::Core::OS;
use AutoLaTeX::TeX::TeXDependencyAnalyzer;
use AutoLaTeX::TeX::BibCitationAnalyzer;
use AutoLaTeX::TeX::IndexAnalyzer;

our $VERSION = '2.0';

my %COMMAND_DEFINITIONS = (
	'pdflatex' => {
		'cmd' => 'pdflatex',
		'flags' => ['-interaction', 'batchmode'],
		'to_dvi' => ['--output-format=dvi'],
		'to_ps' => undef,
		'to_pdf' => ['--output-format=pdf'],
	},
	'latex' => {
		'cmd' => 'latex',
		'flags' => ['-interaction', 'batchmode'],
		'to_dvi' => ['--output-format=dvi'],
		'to_ps' => undef,
		'to_pdf' => ['--output-format=pdf'],
	},
	'xelatex' => {
		'cmd' => 'xelatex',
		'flags' => ['-interaction', 'batchmode'],
		'to_dvi' => ['--no-pdf'],
		'to_ps' => undef,
		'to_pdf' => [],
	},
	'lualatex' => {
		'cmd' => 'luatex',
		'flags' => ['-interaction', 'batchmode'],
		'to_dvi' => ['--output-format=dvi'],
		'to_ps' => undef,
		'to_pdf' => ['--output-format=pdf'],
	},
	'bibtex' => {
		'cmd' => 'bibtex',
		'flags' => [],
	},
	'makeindex' => {
		'cmd' => 'makeindex',
		'flags' => [],
	},
	'dvi2ps' => {
		'cmd' => 'dvips',
		'flags' => [],
	},
);

struct( Entry => [
		'file' => '$',
		'go_up' => '$',
		'rebuild' => '$',
		'parent' => '$',
] );

sub newEntry($$) {
	my $e = Entry->new;
	@$e = ($_[0],0,0,$_[1]);
	return $e;
}

#------------------------------------------------------
#
# Constructor
#
#------------------------------------------------------

sub new(\%) : method {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $parent = ref($proto) && $proto ;

	my $self ;
	if ( $parent ) {
		%{$self} = %{$parent} ;
	}
	else {
		$self = { 
			'configuration' => $_[0],
			'files' => {},
			'rootFiles' => [],
			'is_bibtex_enable' => 1,
			'is_makeindex_enable' => 1,
			'generation_type' => 'pdf',
			'latex_cmd' => [],
			'bibtex_cmd' => [],
			'makeindex_cmd' => [],
			'dvi2ps_cmd' => [],
		};
	}
	bless( $self, $class );

	#
	# Build the different commands according to the current configuration
	#
	$self->{'type'} = $_[0]->{'generation.generation type'} || 'pdf';
	my $compiler = $_[0]->{'generation.tex compiler'} || 'pdflatex';

	# LaTeX
	if ($_[0]->{'generation.latex_cmd'}) {
		push @{$self->{'latex_cmd'}}, $_[0]->{'generation.latex_cmd'};
	}
	else {
		my $def = $COMMAND_DEFINITIONS{"$compiler"};
		confess("No command definition for '$compiler'") unless ($def);
		push @{$self->{'latex_cmd'}}, $def->{'cmd'}, @{$def->{'flags'}};
		confess("No command definition for '$compiler/".$self->{'type'}."'") unless (exists $def->{'to_'.$self->{'type'}});
		my $target = $def->{'to_'.$self->{'type'}};
		if (defined($target)) {
			push @{$self->{'latex_cmd'}}, @{$target};
		}
		elsif ($self->{'type'} eq 'ps') {
			push @{$self->{'latex_cmd'}}, @{$def->{'to_dvi'}};
		}
		else {
			confess('invalided Maker state: cannot find the command line to compile TeX files.');
		}
	}

	if ($_[0]->{'generation.latex_flags'}) {
		my @params = split(/\s+/, ($_[0]->{'generation.latex_flags'}));
		push @{$self->{'latex_flags'}}, @params;
	}

	# BibTeX
	if ($_[0]->{'generation.bibtex_cmd'}) {
		push @{$self->{'bibtex_cmd'}}, $_[0]->{'generation.bibtex_cmd'};
	}
	else {
		my $def = $COMMAND_DEFINITIONS{'bibtex'};
		confess("No command definition for 'bibtex'") unless ($def);
		push @{$self->{'bibtex_cmd'}}, $def->{'cmd'}, @{$def->{'flags'}};
	}

	if ($_[0]->{'generation.bibtex_flags'}) {
		my @params = split(/\s+/, ($_[0]->{'generation.bibtex_flags'}));
		push @{$self->{'bibtex_flags'}}, @params;
	}

	# MakeIndex
	if ($_[0]->{'generation.makeindex_cmd'}) {
		push @{$self->{'makeindex_cmd'}}, $_[0]->{'generation.makeindex_cmd'};
	}
	else {
		my $def = $COMMAND_DEFINITIONS{'makeindex'};
		confess("No command definition for 'makeindex'") unless ($def);
		push @{$self->{'makeindex_cmd'}}, $def->{'cmd'}, @{$def->{'flags'}};
	}

	if ($_[0]->{'generation.makeindex_flags'}) {
		my @params = split(/\s+/, ($_[0]->{'generation.makeindex_flags'}));
		push @{$self->{'makeindex_flags'}}, @params;
	}

	# dvi2ps
	if ($_[0]->{'generation.dvi2ps_cmd'}) {
		push @{$self->{'dvi2ps_cmd'}}, $_[0]->{'generation.dvi2ps_cmd'};
	}
	else {
		my $def = $COMMAND_DEFINITIONS{'dvi2ps'};
		confess("No command definition for 'dvi2ps'") unless ($def);
		push @{$self->{'dvi2ps_cmd'}}, $def->{'cmd'}, @{$def->{'flags'}};
	}

	if ($_[0]->{'generation.dvi2ps_flags'}) {
		my @params = split(/\s+/, ($_[0]->{'generation.dvi2ps_flags'}));
		push @{$self->{'dvi2ps_flags'}}, @params;
	}

	return $self;
}

=pod

=item * reset()

Reset this make tool.

=cut
sub reset() : method {
	my $self = shift;
	$self->{'files'} = {};
	$self->{'rootFiles'} = [];
	return undef;
}

=pod

=item * addTeXFile($)

Add the given TeX file into the building process.
Takes 1 arg:

=over

=item * file (string)

is the name of the TeX file to read.

=back

=cut
sub addTeXFile($) : method {
	my $self = shift;
	my $rootfile = shift;
	$rootfile = File::Spec->rel2abs($rootfile);
	my $rootbasename = basename($rootfile, '.tex');
	my $rootdir = dirname($rootfile);
	my $roottemplate = File::Spec->catfile(dirname($rootfile), "$rootbasename");

	my $pdfFile = "$roottemplate.pdf";
	$self->{'files'}{$pdfFile} = {
		'type' => 'pdf',
		'dependencies' => { $rootfile => undef },
		'change' => lastFileChange($pdfFile),
		'mainFile' => $rootfile,
	};
	push @{$self->{'rootFiles'}}, "$pdfFile";

	my @files = ( $rootfile );
	while (@files) {
		my $file = shift @files;
		printDbgFor(2, locGet(_T("Parsing '{}'"), $file));
		if (-f "$file" ) {
			printDbgIndent();
			$self->{'files'}{$file} = {
				'type' => 'tex',
				'dependencies' => {},
				'change' => lastFileChange($file),
			};
			my %deps = getDependenciesOfTeX($file,$rootdir);
			if (%deps) {
				my $dir = dirname($file);

				#
				# INCLUDED FILES
				#
				foreach my $cat ('tex', 'sty', 'cls') {
					if ($deps{$cat}) {
						foreach my $dpath (@{$deps{$cat}}) {
							if (!File::Spec->file_name_is_absolute($dpath)) {
								$dpath = File::Spec->catfile($dir, $dpath);
							}
							if ($dpath !~ /\.$cat/) {
								$dpath .= ".$cat";
							}
							$self->{'files'}{$dpath} = {
								'type' => $cat,
								'dependencies' => {},
								'change' => lastFileChange($dpath),
							};
							$self->{'files'}{$pdfFile}{'dependencies'}{$dpath} = undef;
							if ($cat eq 'tex') {
								push @files, $dpath;
							}
						}
					}
				}

				#
				# BIBLIOGRAPHY
				#
				if ($deps{'biblio'}) {
					while (my ($bibdb,$bibdt) = each(%{$deps{'biblio'}})) {
						my $bblfile = File::Spec->catfile("$rootdir", "$bibdb.bbl");
						$self->{'files'}{"$bblfile"} = {
							'type' => 'bbl',
							'dependencies' => {},
							'change' => lastFileChange("$bblfile"),
						};
						$self->{'files'}{$pdfFile}{'dependencies'}{$bblfile} = undef;
						
						foreach my $cat ('bib', 'bst') {
							if ($bibdt->{$cat}) {
								foreach my $dpath (@{$bibdt->{$cat}}) {
									if (!File::Spec->file_name_is_absolute($dpath)) {
										$dpath = File::Spec->catfile("$rootdir", $dpath);
									}
									if ($dpath !~ /\.$cat/) {
										$dpath .= ".$cat";
									}
									$self->{'files'}{$dpath} = {
										'type' => $cat,
										'dependencies' => {},
										'change' => lastFileChange($dpath),
									};
									$self->{'files'}{"$bblfile"}{'dependencies'}{$dpath} = undef;
								}
							}
						}
					}					
				}

				#
				# INDEX
				#
				if ($deps{'idx'}) {
					my $idxfile = "$roottemplate.idx";
					$self->{'files'}{"$idxfile"} = {
						'type' => 'idx',
						'dependencies' => {},
						'change' => lastFileChange("$idxfile"),
					};
					my $indfile = "$roottemplate.ind";
					$self->{'files'}{"$indfile"} = {
						'type' => 'ind',
						'dependencies' => { $idxfile => undef },
						'change' => lastFileChange("$indfile"),
					};
					$self->{'files'}{$pdfFile}{'dependencies'}{$indfile} = undef;
				}
			}
			printDbgUnindent();
		}
	}

	return undef;
}

=pod

=item * runLaTeX()

Launch pdfLaTeX once time.

=over 4

=item * C<file> is the name of the PDF or the TeX file to compile.

=item * C<enableLoop> (optional boolean) indicates if this function may loop on the LaTeX compilation when it is requested by the LaTeX tool.

=back

=cut
sub runLaTeX($;$) : method {
	my $self = shift;
	my $file = shift;
	my $enableLoop = shift;
	if ($self->{'files'}{$file}{'mainFile'}) {
		$file = $self->{'files'}{$file}{'mainFile'};
	}
	my $logFile = File::Spec->catfile(dirname($file), basename($file, '.tex').'.log');
	my $continueToCompile;
	do {
		printDbg(locGet(_T('{}: {}'), 'PDFLATEX', basename($file))); 
		$continueToCompile = 0;
		$self->{'warnings'} = {};
		unlink($logFile);
		my $exitcode = runCommandSilently(@{$self->{'latex_cmd'}}, $file);
		local *LOGFILE;
		if ($exitcode!=0) {
			printDbg(locGet(_T("{}: Error when generating {}"), 'PDFLATEX', basename($file)));
			open(*LOGFILE, "< $logFile") or printErr("$logFile: $!");
			while (my $line = <LOGFILE>) {
				print STDERR "$line";
			}
			close(*LOGFILE);
			exit($exitcode);
		}
		elsif ($enableLoop) {
			my $line;
			open(*LOGFILE, "< $logFile") or printErr("$logFile: $!");
			my $lastline = '';
			while (!$continueToCompile && ($line = <LOGFILE>)) {
				$lastline .= $line;
				if ($lastline =~ /\.\s*$/) {
					if ($self->_testLaTeXWarningOn($lastline)) {
						$continueToCompile = $enableLoop;
					}
					$lastline = '';
				}
			}
			if ($lastline =~ /\.\s*$/ && $self->_testLaTeXWarningOn($lastline)) {
				$continueToCompile = $enableLoop;
			}
			close(*LOGFILE);
		}
	}
	while ($continueToCompile);
	return 0;
}

sub _testLaTeXWarningOn($) : method {
	my $self = shift;
	my $line = shift;
	if ($line =~ /Warning.*\s+re\-?run\s+/i) {
		return 1;
	}
	elsif ($line =~ /Warning\s*:\s+There\s+were\s+undefined\s+references/i) {
		$self->{'warnings'}{'undefined_reference'} = 1;
	}
	elsif ($line =~ /Warning\s*:\s+Citation.+undefined/i) {
		$self->{'warnings'}{'undefined_citation'} = 1;
	}
	elsif ($line =~ /Warning\s*:\s+There\s+were\s+multiply-defined\s+labels/i) {
		$self->{'warnings'}{'multiple_definition'} = 1;
	}
	elsif ($line =~ /Warning/i) {
		$self->{'warnings'}{'other_warning'} = 1;
	}
	return 0;
}

=pod

=item * build()

Build all the root files.

=cut
sub build() : method {
	my $self = shift;

	foreach my $rootFile (@{$self->{'rootFiles'}}) {
		# Read building stamps
		$self->_readBuildStamps($rootFile);

		# Launch at least one LaTeX compilation
		$self->runLaTeX($rootFile);

		# Construct the build list and launch the required builds
		my @builds = $self->_buildExecutionList("$rootFile");
		if (@builds) {
			foreach my $file (@builds) {
				$self->_build($rootFile, $file);
			}
		}
		else {
			printDbgFor(2, locGet(_T('{} is up-to-date.'), basename($rootFile)));
		}

		# Write building stamps
		$self->_writeBuildStamps($rootFile);

		# Generate the Postscript file when requested
		if (($self->{'configuration'}{'generation.generation type'}||'pdf') eq 'ps') {
			my $dirname = dirname($rootFile);
			my $basename = basename($rootFile, '.pdf', '.ps', '.dvi', '.xdv');
			my $dviFile = File::Spec->catfile($dirname, $basename.'.dvi');
			my $dviDate = lastFileChange("$dviFile");
			if (defined($dviDate)) {
				my $psFile = File::Spec->catfile($dirname, $basename.'.ps');
				my $psDate = lastFileChange("$psFile");
				if (!$psDate || ($dviDate>=$psDate)) {
					printDbg(locGet(_T('{}: {}'), 'DVI2PS', basename($dviFile))); 
					runCommandOrFail(@{$self->{'dvi2ps_cmd'}}, $dviFile);
				}
			}
		}

		# Output the last LaTeX warning indicators.
		if ($self->{'warnings'}{'multiple_definition'}) {
			print STDERR locGet(_T("LaTeX Warning: There were multiply-defined labels.\n"));
		}
		if ($self->{'warnings'}{'undefined_reference'}) {
			print STDERR locGet(_T("LaTeX Warning: There were undefined references.\n"));
		}
		if ($self->{'warnings'}{'undefined_citation'}) {
			print STDERR locGet(_T("LaTeX Warning: There were undefined citations.\n"));
		}
		if ($self->{'warnings'}{'other_warning'}) {
			my $texFile = $rootFile;
			if ($self->{'files'}{$rootFile}{'mainFile'}) {
				$texFile = $self->{'files'}{$rootFile}{'mainFile'};
			}
			my $logFile = File::Spec->catfile(dirname($texFile), basename($texFile, '.tex').'.log');
			print STDERR locGet(_T("LaTeX Warning: Please look inside {} for the other the warning messages.\n"),
					basename($logFile));
		}

	}

	return undef;
}

=pod

=item * buildBibTeX()

Launch the BibTeX only.

=cut
sub buildBibTeX() : method {
	my $self = shift;

	foreach my $rootFile (@{$self->{'rootFiles'}}) {
		# Read building stamps
		$self->_readBuildStamps($rootFile);

		# Construct the build list and launch the required builds
		my @builds = $self->_buildExecutionList("$rootFile",1);
		if (@builds) {
			foreach my $file (@builds) {
				if (exists $self->{'files'}{$file}) {
					my $type = $self->{'files'}{$file}{'type'};
					if ($type eq 'bbl') {
						my $func = $self->can('__build_'.lc($type));
						if ($func) {
							$func->($self, $rootFile, $file, $self->{'files'}{$file});
							return undef;
						}
					}
				}
			}
		}
		else {
			printDbgFor(2, locGet(_T('{} is up-to-date.'), basename($rootFile)));
		}

		# Write building stamps
		$self->_writeBuildStamps($rootFile);
	}

	return undef;
}

=pod

=item * buildMakeIndex()

Launch the MakeIndex only.

=cut
sub buildMakeIndex() : method {
	my $self = shift;

	foreach my $rootFile (@{$self->{'rootFiles'}}) {
		# Read building stamps
		$self->_readBuildStamps($rootFile);

		# Construct the build list and launch the required builds
		my @builds = $self->_buildExecutionList("$rootFile",1);
		if (@builds) {
			foreach my $file (@builds) {
				if (exists $self->{'files'}{$file}) {
					my $type = $self->{'files'}{$file}{'type'};
					if ($type eq 'ind') {
						my $func = $self->can('__build_'.lc($type));
						if ($func) {
							$func->($self, $rootFile, $file, $self->{'files'}{$file});
							return undef;
						}
					}
				}
			}
		}
		else {
			printDbgFor(2, locGet(_T('{} is up-to-date.'), basename($rootFile)));
		}

		# Write building stamps
		$self->_writeBuildStamps($rootFile);
	}

	return undef;
}

# Read the building stamps.
# This function puts the stamps in $self->{'stamps'}.
# Parameter:
# $_[0] = path to the root TeX file.
# Result: nothing
sub _readBuildStamps($) : method {
	my $self = shift;
	my $rootFile = shift;
	my $stampFile = File::Spec->catfile(dirname($rootFile), '.autolatex_stamp');
	if (exists $self->{'stamps'}) {
		delete $self->{'stamps'};
	}
	if (-r "$stampFile") {
		local *FILE;
		open(*FILE, "< $stampFile") or printErr("$stampFile: $!");
		while (my $line = <FILE>) {
			if ($line =~ /^BIB\(([^)]+?)\)\:(.+)$/) {
				my ($k,$n) = ($1,$2);
				$self->{'stamps'}{'bib'}{$n} = $k;
			}
			if ($line =~ /^IDX\(([^)]+?)\)\:(.+)$/) {
				my ($k,$n) = ($1,$2);
				$self->{'stamps'}{'idx'}{$n} = $k;
			}
		}
		close(*FILE);
	}
}

# Write the building stamps.
# This function gets the stamps from $self->{'stamps'}.
# Parameter:
# $_[0] = path to the root TeX file.
# Result: nothing
sub _writeBuildStamps($) : method {
	my $self = shift;
	my $rootFile = shift;
	my $stampFile = File::Spec->catfile(dirname($rootFile), '.autolatex_stamp');
	local *FILE;
	open(*FILE, "> $stampFile") or printErr("$stampFile: $!");
	if ($self->{'stamps'}{'bib'}) {
		while (my ($k,$v) = each(%{$self->{'stamps'}{'bib'}})) {
			print FILE "BIB($v):$k\n";
		}
	}
	if ($self->{'stamps'}{'idx'}) {
		while (my ($k,$v) = each(%{$self->{'stamps'}{'idx'}})) {
			print FILE "IDX($v):$k\n";
		}
	}
	close(*FILE);
}

# Static function that is testing if the timestamp a is
# more recent than the timestamp b.
# Parameters:
# $_[0] = a.
# $_[1] = b.
# Result: true if a is more recent than b, or not defined;
#         false otherwise.
sub _a_more_recent_than_b($$) {
	my $a = shift;
	my $b = shift;
	return (!defined($a) || (defined($b) && $a>$b));
}

# Test if the specified file is needing to be rebuild.
# Parameters:
# $_[0] = timestamp of the root file.
# $_[1] = filename of the file to test.
# $_[2] = parent element of the file, of type Entry.
# $_[3] = is the description of the file to test.
# Result: true if the file is needing to be rebuild,
#         false if the file is up-to-date.
sub _need_rebuild($$$$) : method {
	my $self = shift;
	my $rootchange = shift;
	my $filename = shift;
	my $parent = shift;
	my $file = shift;
	if (!defined($file->{'change'}) || (!-f "$filename")) {
		return 1;
	}

	if ($filename =~ /(\.[^.]+)$/) {
		my $ext = $1;
		if ($ext eq '.bbl') {
			# Parse the AUX file to detect the citations
			my $auxFile = File::Spec->catfile(dirname($filename), basename($filename, '.bbl').'.aux');
			my $currentMd5 = makeAuxBibliographyCitationMd5($auxFile) || '';
			my $oldMd5 = $self->{'stamps'}{'bib'}{$auxFile} || '';
			if ($currentMd5 ne $oldMd5) {
				$self->{'stamps'}{'bib'}{$auxFile} = $currentMd5;
				return 1;
			}
			return 0;
		}
		elsif ($ext eq '.ind') {
			# Parse the IDX file to detect the index definitions
			my $idxFile = File::Spec->catfile(dirname($filename), basename($filename, '.ind').'.idx');
			my $currentMd5 = makeIdxIndexDefinitionMd5($idxFile) || '';
			my $oldMd5 = $self->{'stamps'}{'idx'}{$idxFile} || '';
			if ($currentMd5 ne $oldMd5) {
				$self->{'stamps'}{'idx'}{$idxFile} = $currentMd5;
				return 1;
			}
			return 0;
		}
	}

	return _a_more_recent_than_b( $file->{'change'}, $rootchange );
}

# Build the list of the files to be build.
# Parameters:
# $_[0] = name of the root file that should be build.
# $_[1] = boolean value that permits to force to consider all the files has changed.
# Result: the build list.
sub _buildExecutionList($;$) : method {
	my $self = shift;
	my $rootfile = shift;
	my $forceChange = shift;
	my @builds = ();

	# Go through the dependency tree with en iterative algorithm

	my $rootchange = $self->{'files'}{$rootfile}{'change'};
	my $element = newEntry($rootfile,undef) ;
	my $child;
	my @iterator = ( $element );	
	while (@iterator) {
		$element = pop @iterator;
		my $deps = $self->{'files'}{$element->file}{'dependencies'};
		if ($element->go_up || !%$deps) {
			if (	$forceChange ||
				$element->rebuild ||
				$self->_need_rebuild(
					$rootchange,
					$element->file,
					$element->parent,
					$self->{'files'}{$element->file})) {

				if ($element->parent) {
					$element->parent->rebuild(1);
				}

				if ($self->can('__build_'.lc($self->{'files'}{$element->file}{'type'}))) {
					push @builds, $element->file;
				}

			}
		}
		else {
			push @iterator, $element;
			foreach my $dep (keys %$deps) {
				$child = newEntry($dep,$element);
				push @iterator, $child;
			}
			$element->go_up(1);
		}
	}
	return @builds;
}

# Run the building process.
# Parameters:
# $_[0] = name of the root file that should be build.
# $_[1] = name of the file to build (the root file or one of its dependencies).
# Result: nothing.
sub _build($$) : method {
	my $self = shift;
	my $rootFile = shift;
	my $file = shift;

	if (exists $self->{'files'}{$file}) {
		my $type = $self->{'files'}{$file}{'type'};
		if ($type) {
			my $func = $self->can('__build_'.lc($type));
			if ($func) {
				$func->($self, $rootFile, $file, $self->{'files'}{$file});
				return undef;
			}
		}
	}

	# Default building behavior: do nothing
	return undef;
}

# Callback to build a BBL file.
# Parameters:
# $_[0] = name of the root file that should be build.
# $_[1] = name of the file to build (the root file or one of its dependencies).
# $_[2] = description of the file to build.
# Result: nothing.
sub __build_bbl($$$) : method {
	my $self = shift;
	my $rootFile = shift;
	my $file = shift;
	my $filedesc = shift;
	if ($self->{'is_bibtex_enable'}) {
		my $basename = basename($file,'.bbl');
		my $auxFile = File::Spec->catfile(dirname($file),"$basename.aux");
		printDbg(locGet(_T('{}: {}'), 'BIBTEX', basename($auxFile))); 
		runCommandOrFail(@{$self->{'bibtex_cmd'}}, "$auxFile");
	}
}

# Callback to build a IND file.
# Parameters:
# $_[0] = name of the root file that should be build.
# $_[1] = name of the file to build (the root file or one of its dependencies).
# $_[2] = description of the file to build.
# Result: nothing.
sub __build_ind($$$) : method {
	my $self = shift;
	my $rootFile = shift;
	my $file = shift;
	my $filedesc = shift;
	if ($self->{'is_makeindex_enable'}) {
		my $basename = basename($file,'.ind');
		my $idxFile = File::Spec->catfile(dirname($file),"$basename.idx");
		printDbg(locGet(_T('{}: {}'), 'MAKEINDEX', basename($idxFile))); 
		my @styleArgs = ();
		my $istFile = $self->{'configuration'}{'__private__'}{'output.ist file'};
		if ($istFile && -f "$istFile") {
			printDbgFor(2, locGet(_T('Style file: {}'), $istFile)); 
			push @styleArgs, '-s', "$istFile";
		}
		runCommandOrFail(@{$self->{'makeindex_cmd'}}, @styleArgs, "$idxFile");
	}
}

# Callback to build a PDF file.
# Parameters:
# $_[0] = name of the root file that should be build.
# $_[1] = name of the file to build (the root file or one of its dependencies).
# $_[2] = description of the file to build.
# Result: nothing.
sub __build_pdf($$$) : method {
	my $self = shift;
	my $rootFile = shift;
	my $file = shift;
	my $filedesc = shift;
	my $runs = 2;
	my $majorFailure = 0;
	do {
		$runs--;
		$self->runLaTeX($file,1);
		$majorFailure = (exists $self->{'warnings'}{'multiple_definition'}) ||
				(exists $self->{'warnings'}{'undefined_reference'}) ||
				(exists $self->{'warnings'}{'undefined_citation'});
	}
	while ($majorFailure && $runs>0);
}

=pod

=item * enableBibTeX

Enable or disable the call to bibtex.
If this function has a parameter, the flag is changed.

=over

=item * isEnable (optional boolean)

=back

I<Returns:> the vlaue of the enabling flag.

=cut
sub enableBibTeX : method {
	my $self = shift;
	if (@_) {
		$self->{'is_bibtex_enable'} = $_[0];
	}
	return $self->{'is_bibtex_enable'};
}

=pod

=item * enableBibTeX

Enable or disable the call to bibtex.
If this function has a parameter, the flag is changed.

=over

=item * isEnable (optional boolean)

=back

I<Returns:> the vlaue of the enabling flag.

=cut
sub enableMakeIndex : method {
	my $self = shift;
	if (@_) {
		$self->{'is_makeindex_enable'} = $_[0];
	}
	return $self->{'is_makeindex_enable'};
}

=pod

=item * generationType

Get or change the type of generation.
If this function has a parameter, the type is changed.

=over

=item * type (optional string)

C<"pdf"> to use pdflatex, C<"dvi"> to use latex, C<"ps"> to use latex and dvips, C<"pspdf"> to use latex, dvips and ps2pdf.

=back

I<Returns:> the generation type.

=cut
sub generationType : method {
	my $self = shift;
	if (@_) {
		my $type = $_[0];
		if ($type ne 'dvi' && $type ne 'ps' && $type ne 'pdf') {
			$type = 'pdf';
		}
		$self->{'generation_type'} = $type;
	}
	return $self->{'generation_type'};
}

1;
__END__
=back

=head1 BUG REPORT AND FEEDBACK

To report bug, provide feedback, suggest new features, etc. visit the AutoLaTeX Project management page at <http://www.arakhne.org/autolatex/> or send email to the author at L<galland@arakhne.org>.

=head1 LICENSE

S<GNU Public License (GPL)>

=head1 COPYRIGHT

S<Copyright (c) 2013 Stéphane Galland E<lt>galland@arakhne.orgE<gt>>

=head1 SEE ALSO

L<autolatex-dev>
