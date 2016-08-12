use strict;

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

my $ndxdiv = 25;


sub make_index
{
   my $filename = $_[0];
   open F, $filename or die "Cannot open $filename:$!\n";
   my %idxpos;
   # creating index
   if ( open FF, "> $filename.idx") { 
      my $pos = 0;
      my $lastpos = 0;
      my @order;
      print STDERR "creating index file #1...";
      while (<F>) {
         $lastpos = $pos;
         $pos = tell F;
         s/\`//g;
         next unless /^<b>(?:[XVI]+\.\s)*([^\)\(<\s'.-])[\s'.-]*([^\)\(<'.-])/;
         next unless exists $lc{$1};
         my $key = $lc{$1};
         if (($2 ne ' ') && exists $lc{$2}) {
            if ( !exists $idxpos{$key}) { # 2-letter exists, but 1-letter don't
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
      die "Error during creating $filename.idx" unless $succeed;
   } else {
      die "Cannot create index file $filename.idx:$!\n"; 
   }


   if ( open FF, "> $filename.ndx") { 
      my @ndxpos;
      my $count = 0;
      my $lastword = '';
      print STDERR "creating index file #2...";
      my $lastpos = 0;
      my $pos = 0;
      while (<F>) {
         $lastpos = $pos;
         $pos = tell F;
         next unless /^<b>(?:[XVI]+\.\s)*(.*) <\/b>/;
         next if $1 eq $lastword;
         #$pos = $lastpos, next if $1 eq $lastword;
         $lastword = $1;
         push ( @ndxpos, $lastpos) unless $count % $ndxdiv;
         $count++;
      }
      my $succeed = 1;
      print FF "ndx count $count div $ndxdiv\n";
      for ( @ndxpos) {
         $succeed = 0, last unless print FF "$_\n";
      }
      $succeed |= close FF;
      print STDERR $succeed ? "ok.\n" : "failed\n";
      die "Error during creating $filename.ndx" unless $succeed;
   } else {
      die "Cannot create index file $filename.ndx:$!\n"; 
   }

   close F;
}

die "format: file.html\n" if @ARGV < 1;
make_index( $ARGV[0]);
