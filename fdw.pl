#!/usr/bin/perl -w
# $Id: fdw.pl,v 1.2 2008/09/30 11:28:04 dk Exp $

# text-only interface to danish-english and english-danish 
# dictionaries, html version.
#
# created by Dmitry Karasik <dmitry@karasik.eu.org>

use strict;

my $specOpts = <<SO;
special characters may be set as follow:
  (ø) O  crossed   - /o or  /O
  (æ) AE diaglyph  - /ae or /AE
  (å) A ring       - /aa or /AA
Options are:
   -7    - treat special characters for 7-bit output as o/, ae, aa.
   -70   - no 7-bit coding
   -71   - treat special characters for 7-bit output as \/o, \/ae, \/aa.
   -b/-v - be brief / be verbose                 (default -v)
   -s/-m - print single match / multiple matches (default -s)
   -w/-p - look for whole / for part of the word (default -p)
   -a/-A - turn on/off ansi highlighting         (default -A)
SO

die <<DIE if @ARGV < 1;
format: fwd wordlist [ word [[options]]
$specOpts   -i    - be interactive. same without word given.
   -X    - inhibit index creation and usage.

NB: at first run, the program creates the index file for
the dictionary. It takes some time, but speeds up the search later.
However, if program cannot write down the index, it can live without,
but work slower. If any changes need to be applied to the dictionary
file, index file must be deleted to be automatically regenerated at
the next run again.
DIE

my $filename = shift @ARGV;
my $word     = (( $ARGV[0] || '') =~ /^\-/) ? undef : shift(@ARGV);
my $i;
my $seven = 2;
my $interactive = 0;
my $brief  = 0;
my $fm     = 1;
my $whole  = 0;
my $doIndex = 1;
my $ansi    = 0;

my $useIndex = 0;
my %lc = map {
	$_ => lc($_),
} ('A' .. 'Z', 'a' .. 'z');
$lc{'ø'} = 'ø';
$lc{'æ'} = 'æ';
$lc{'å'} = 'å';
$lc{'Ø'} = 'ø';
$lc{'Æ'} = 'æ';
$lc{'Å'} = 'å';
$lc{'á'} = 'a';

sub option
{
	$_ = $_[0];
	return 0 unless m/^\-/;
	s/^\-//;
	if ( $_ eq '7') {
		$seven = 0;
	} elsif ( $_ eq '71') {
		$seven = 1;
	} elsif ( $_ eq '70') {
		$seven = 2;
	} elsif ( $_ eq 'b') {
		$brief = 1;
	} elsif ( $_ eq 'v') {
		$brief = 0;
	} elsif ( $_ eq 's') {
		$fm = 1;
	} elsif ( $_ eq 'p') {
		$whole = 0;
	} elsif ( $_ eq 'w') {
		$whole = 1;
	} elsif ( $_ eq 'm') {
		$fm = 0;
	} elsif ( $_ eq 'a') {
		$ansi = 1;
	} elsif ( $_ eq 'A') {
		$ansi = 0;
	} else {
		return 0;
	}
	return 1; 
}

for ( $i = 0; $i < @ARGV; $i++) {
	$_ = $ARGV[$i];
	die "Invalid option: $_\n" unless $_ =~ /^\-/;
	s/^\-//;
	last if $_ eq '-'; 
	next if option( $ARGV[$i]);
	if ( $_ eq 'X') {
		$doIndex = 0;
	} elsif ( $_ eq 'i') {
		$interactive = 1;
	} else {
		die "Unknown option:$_\n";
	}
}

open F, $filename or die "Cannot open $filename:$!\n";

my %idxpos; 
if ( $doIndex) {
	if ( open FF, "$filename.idx") {
		while (<FF>) {
			chomp;
			next unless /^([\S]+)\s(\d+)(\D*)$/;
			$idxpos{$1} = $2;
		}
		close FF;
		$useIndex = 1;
		if ( scalar( keys %idxpos) < 2)  {
			warn "You may experience the problems, since index file is not valid\n";
		}
	} else {
	# creating index
		if ( open FF, "> $filename.idx") { 
			my $pos = 0;
			my $lastpos = 0;
			my @order;
			print STDERR "creating index file...";
			binmode F;
			while (<F>) {
				$lastpos = $pos;
				$pos = tell F;
				s/\`//g;
				next unless /^<b>(?:[XVI]+\.\s)*([^\)\(<\s'.-])[\s'.-]*([^\)\(<'.-])/;
				next unless exists $lc{$1};
				my $key = $lc{$1};
				if (($2 ne ' ') && exists $lc{$2}) {
					# 2-letter exists, but 1-letter don't
					if ( !exists $idxpos{$key}) { 
						$idxpos{$key} = $lastpos;
						push( @order, $key);
					}
					$key .= $lc{$2};
				}
				next if exists $idxpos{$key};
				$idxpos{$key} = $lastpos;
				push( @order, $key);
			}
			seek( F, 0, 0);
			my $succeed = 1;
			for ( @order) {
				$succeed = 0, last unless print FF "$_ $idxpos{$_}\n";
			}
			$succeed |= close FF;
			print STDERR $succeed ? "ok.\n" : "failed\n";
			$useIndex = 1 if $succeed;
		} else {
			warn "Cannot create index file $filename.idx:$!\n"; 
		}
	}
}

sub status
{
return split("\n", <<STATUS);
  7-bit enc        : $seven
  brief            : $brief
  whole word match : $whole
  single match     : $fm
  ansi output      : $ansi
STATUS
}

sub find {
	my @ret;
	my $stage = 0;

	my $fstr  = $_[0];
	$fstr =~ s/(\/O|\/o)/ø/g;   # O/
	$fstr =~ s/(\/AE|\/ae)/æ/g; # AE
	$fstr =~ s/(\/AA|\/aa)/å/g; # A ring
#  $fstr = quotemeta( $fstr);
	my $fcr  = $lc{substr( $fstr, 0, 1)};
	my $fcr2;
	if ( length($fstr) > 1) {
		$fcr2 = $lc{substr($fstr, 1, 1)};
	} else {
		$fcr2 = ' ';
	}
	$fstr .= ' ' if $whole;
	my $firstMatch;
	my $noMatch = 0;

	if ( $useIndex) {
		return unless defined($fcr) && defined($idxpos{$fcr});
		return unless defined $fcr2;
		if ( $fcr2 eq ' ') { # single-byte word
			seek( F, $idxpos{$fcr}, 0); 
			$stage = 1;
		} elsif ( defined $idxpos{$fcr.$fcr2}) {
			seek( F, $idxpos{$fcr.$fcr2}, 0);  
			$stage = 1;
		} else {
			return;
		}
	}
	
	while (<F>) {
		s/\&nbsp;/ /g;
		s/\&amp;/\&/g;
		my $save = $_;
		s/\`|\(|\)//g; # exclude `() from search
		unless ( /^<b>(?:[XVI]+\.\s)*$fstr/i) {
			if ( $stage && m/^<b>(?:[XVI]+\.\s)*([^<\s'.-])[\s'.-]*([^<'.-])/) {
				my $cr = $lc{$1};
				last if defined($cr) && defined($fcr) && ($cr ne $fcr);
				last if defined($fcr2) && defined ($lc{$2}) && ( $lc{$2} ne $fcr2);
			}
			next;
		}

		if ( $fm) {
			if ( m/^<b>(?:[XVI]+\.\s)*([^<]*)</) {
				if ( defined $firstMatch) {
					$noMatch = 1 if $1 ne $firstMatch;
				} else {
					$firstMatch = $1;
				}
			} else {
				$noMatch = 1;
			}
		}
		
		$_ = $save;
		s/<br>/\n/g;
		if ( $ansi) {
			s/<b>/\e[1;34m/g;                
			s/<\/b>/\e[0m/g;
			s/<i>/\e[1;33m/g;                
			s/<\/i>/\e[0m/g;      
		} else {
			s/(<b>|<\/b>|<i>|<\/i>)//g;
		}

		s/<!--\*ex-->.*//s if $brief;
		s/<!--[^-]*-->//s; # strip comments
		if ( $seven == 0) {
			s/ø/o\//g;
			s/æ/ae/g;
			s/å/aa/g;
			s/Ø/O\//g;
			s/Æ/AE/g;
			s/Å/Aa/g;
		} elsif ( $seven == 1) {
			s/ø/\/o/g;
			s/æ/\/ae/g;
			s/å/\/aa/g;
			s/Ø/\/O/g;
			s/Æ/\/AE/g;
			s/Å/\/AA/g;
		}
		$stage = 1;
		last if $fm && $noMatch;
		push @ret, $_;
	}
	return @ret;
}

if ( $interactive or (!defined $word)) {
	print "*** $filename ****\n";
	print "*** Enter -h for help ***\n";
	print "*** Enter search word, <CR> to quit ***\n";
	while ( 1) {
		print ":";
		my $z = <STDIN>;
		chomp $z;
		if ( $z =~ m/^\-(.)/) {
			my @status = status();
			if ( $z eq '-h') {
				print "\n\n";
				print $specOpts;
				print "Status:\n";
				print join("\n", @status);
				print "\n*** Enter search word, <CR> to quit ***\n"; 
			} elsif ( option( $z)) {
				my @nst = status();
				my $i;
				for ( $i = 0; $i < @nst; $i++) {
					next if $nst[$i] eq $status[$i];
					print $nst[$i] , "\n";
				}
			} else {
				print "Unknown command\n";
			}
			next;
		}
		last unless length $z;
		my @z = find($z);
		print scalar(@z) ? (@z) : "Not found\n";
	}
} else {
	print find( $word);
}

close F;
