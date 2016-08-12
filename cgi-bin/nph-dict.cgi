#! /usr/bin/perl -w -T

use strict;
require URI::URL;
use lib '.';
use CGI::Carp qw(fatalsToBrowser);
use CGI qw(:standard :html3 :push -nph);
use Cwd;
use Fcntl ':flock'; 
$|=1;

sub load_error
{
   print start_html;
   print <<SD;
<p>
<h3>File load error</h3>
<p>
The file <b>$_[0]</b> could not be located.<br>
Please contact the webmaster</a>.<p>
SD
   print end_html;
   $|=1;
   exit(0);
}  

sub edie
{
   print start_html;
   print <<SD;
<p>
<h3>Software error</h3>
<p>
$_[0]<br>
Please contact the webmaster</a>.<p>
SD
   print end_html;
   $|=1;
   exit(0);
}

my $root = '/usr/home/dk/www/dict';

if ( defined ($ENV{REMOTE_ADDR})) {
   my @b = (
      [192,38,108,138,192,38,108,138], 
      [130,227,242,0,130,227,242,255],
   );
   my @a = split('\.', $ENV{REMOTE_ADDR});
   for ( @b) {
      if ( $a[0] >= $$_[0] && $a[0] <= $$_[4] && 
           $a[1] >= $$_[1] && $a[1] <= $$_[5] && 
           $a[2] >= $$_[2] && $a[2] <= $$_[6] && 
           $a[3] >= $$_[3] && $a[3] <= $$_[7]) {
           open F, ">> $root/bumped";
           print F $ENV{REMOTE_ADDR}, ":", scalar(localtime), "\n";
           close F;
           print start_html;
           print <<SD;
Access denied
SD
      print end_html;
      $|=1;
      exit(0);
      }
   }
}

my $lang = param('langref') || 'daen';
$lang = param('selector') if param('switch');
my $type = param('type');
if ( defined $type) {
   if ( $type eq 'master') {
      $type = 2;
   } elsif ( $type eq 'slave') {
      $type = 1;
   } else {
      $type = 0;
   }
} else {
   $type = 0;
}

my %map = (
  'enda' => [{
     '\$NAME'    => 'English-Danish',
     '\$LANG'    => 'english',
     '\$LANGREF' => 'enda',
  }, 'engelsk-dansk.html',
  ],
  'daen' => [{
     '\$NAME'    => 'Danish-English',
     '\$LANG'    => 'danish',
     '\$LANGREF' => 'daen',
  }, 'dansk-engelsk.html',
  ],
);


edie "Can't find appropriate language for $lang\n" unless defined $map{$lang};
my $mm = $map{$lang}->[0];

for ( qw(brief multi whole)) {
   my $key = '\$' . uc($_);
   $mm->{$key} = param($_) ? 'checked' : '';
}

my $num = param('7bit');
$num = 0 unless defined $num;
for ( 0..2) {
   my $key = '\$ESEL' . $_;
   $mm-> {$key} = ( $_ == $num) ? 'checked' : '';
}

for ( keys %map) {
   $mm-> {'\$SELECTOR' . $_} = ( $_ eq $lang) ? 'selected' : '';
}

$mm->{'\$WORD'}       = param('word') || '';
$mm->{'\$LANGREF'}    = $lang;
$mm->{'\$FORMEXTRAS'} = $type ? 'target="output"' : '';
$mm->{'\$SLAVE'}      = $type ? '<input type="hidden" name="type" value="slave">' : '';
$mm->{'\$MASTER'}     = $type ? '<input type="hidden" name="type" value="master">' : '';
$mm->{'\$JSMASTER'}   = $type ? '+"&type=master"' : '';

print header;

my $cnt = -1;

my $ip = '';
if ( defined ($ENV{REMOTE_ADDR})) {
   my $skip;
   if ( open F, "$root/lastip") {
      $ip = <F>;
      close F;
      chomp $ip;
      if ( $ip eq $ENV{REMOTE_ADDR}) {
         $skip = 1;
      } 
   } 
   if ( !$skip && open( F, "> $root/lastip")) {
      print F $ENV{REMOTE_ADDR};
      close F;
   }
   open F, "+< $root/counter";
   flock(F, LOCK_EX);
   $cnt = <F>;
   chomp $cnt;
   $cnt = 0 unless $cnt =~ /^\d+$/;
   unless ( $skip) {
      seek( F, 0, 0);
      $cnt++;
      print F $cnt;
   }
   flock(F, LOCK_UN);
   close F;
} else {
   $cnt = -2;
}

if ( $type != 1) { # not for slave
   load_error("$root/header.html") unless open F1, "$root/header.html";

   while ( <F1>) {
     my $w = $_;
     for ( keys %$mm) {
        my $gn = $_;
        $w =~ s/$gn\b/$$mm{$_}/g;
     }
     print $w;
   }
   close F1;
   print '<hr>' unless $type;
} else {
   print <<MINIHDR;
<html>
<BODY BGCOLOR="#CCCCCC" BACKGROUND="/dk/dict/dk2.gif">
MINIHDR
}

goto EXIT unless length ( param('word') || '');

$mm = $map{$lang}->[1];
load_error("$root/$mm.idx") unless open F2, "$root/$mm.idx";
my %idxpos;
my $whole = param('whole');
my $brief = param('brief');
my $fm    = param('multi') ? 0 : 1;
my $seven = param('7bit') || 0;

while (<F2>) {
   chomp;
   next unless /^([\S]+)\s(\d+)(\D*)$/;
   $idxpos{$1} = $2;
}
close F2;
if ( scalar( keys %idxpos) < 2)  {
   print "<b>You might experience problems, since the index file is not valid!<b><p>\n";
}


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



sub find {
   my @ret;
   my $stage = 0;

   my $fstr  = $_[0];
   $fstr =~ s/(\/O|\/o)/ø/g;   # O/
   $fstr =~ s/(\/AE|\/ae)/æ/g; # AE
   $fstr =~ s/(\/AA|\/aa)/å/g; # A ring
   $fstr =~ s/[\$\[\]\%\@\^\(\)\?\|\+\*]//g;
#  $fstr = quotemeta($fstr);
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
      

   if ( 1) {
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
         if ( m/^<b>(?:[XVI]+\.\s)*(\S*[^<]*)</) {
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
      s/<!--\*ex-->.*//s if $brief;
      s/<!--[^-]*-->//s; # strip comments
      if ( $seven == 0) {
         s/ø/\&\#248;/g;
         s/æ/\&\#230;/g;
         s/å/\&\#229;/g;
         s/Ø/\&\#216;/g;
         s/Æ/\&\#198;/g;
         s/Å/\&\#197;/g;
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

load_error("$root/$mm") unless open F, "$root/$mm";
my $word = param('word');
while (1) {
   my @ret = find($word);
   if ( scalar @ret) {
      print @ret;
      last;
   }
   substr( $word, -1, 1) = '';
   next if length $word;
   print '<i>', param('word'), '</i> not found.<br>';
   last;
}
close F;

EXIT:
print <<CNT unless $type;
<font size=1 color=#808080>$cnt hits since 7 Dec 2000<p>You are:$ENV{REMOTE_ADDR}<br>Last hit: $ip</font>
CNT
print <<END;
</body>
</html>
END

exit(0);
