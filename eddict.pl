#!/usr/bin/perl -w
# $Id: eddict.pl,v 1.1.1.1 2005/07/26 09:16:11 dk Exp $

=pod

=head1 NAME

Danish-English and English-Danish dictionary.

=head1 USAGE

The program presents a browsable, alphabetically-sorted 
word list which can be searched fast by typing or sliding
scroll bar. Double-click or enter key on the window presents
a card window with a translation. Words in translation window
can be translated back by double-clicking on them.

If the danish keyboard layout is not available, the a-ring,
o-slash and ae-diaglyph can be emulated by entering correspondingly
/aa, /o and /ae combinations ( so "year" becomes "/aar", etc ). 

In case the program fails to start and asks for index file
rebuilding, select the menu "Options/Rebuild index files" and
restart the program.

=head1 AUTHOR

Dmitry Karasik, <dmitry@karasik.eu.org>
http://www.karasik.eu.org/

The dictionary home page is http://www.karasik.eu.org/dict

Prima toolkit homepage is http://www.prima.eu.org

=cut

package AbstractListBox;
use vars qw(@ISA);
@ISA = qw(Prima::AbstractListViewer);

sub draw_items
{
	shift-> std_draw_text_items(@_);
}


use Prima qw(PodView Notebooks InputLine Lists IniFile);
use strict;
use Prima::Application name => 'Dictionary';

my $w;
my $card;
my $lock;
my $fd;
my $current = 'd';
my $path = './';
my $noix;

my @scrollbars = Prima::Application-> get_default_scrollbar_metrics;
$::application-> icon(Prima::Icon-> load($path . 'logo.gif'));
$::application-> autoClose(0);

my $iniFile = Prima::IniFile-> create( ($ENV{HOME} || '.') . '/.eddict');
my $ini = $iniFile->section( 'Options' );
my $font = Prima::Widget-> get_default_font;
my %default_ini = (
'WinWidth'  => 300,
'WinHeight' => 300,
'CardTop'   => 'auto',
'CardLeft'  => 100,
'CardWidth' => 300,
'CardHeight'=> 200,
'FontName'  => $font-> {name},
'FontSize'  => $font-> {size},
'FontStyle' => $font-> {style},
'FontEncoding' => $font-> {encoding},
);

for ( keys %default_ini) {
	$ini-> {$_} = $default_ini{$_} unless exists $ini-> {$_};
}

my %data = (
'd' => {
	idx    => {},
	ndx    => [],
	count  => 0,
	div    => 25,
	ncache => {},

	page   => 0,
	ltop   => 0,
	lfoc   => 0,
},
'e' => {
	idx    => {},
	ndx    => [],
	count  => 0,
	div    => 25,
	ncache => {},
	
	page   => 1,
	ltop   => 0,
	lfoc   => 0,
},
);

sub warning
{
	require Prima::MsgBox;
	Prima::MsgBox::message( $_[0]);
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

my $ndxdiv = 25;

sub make_index
{
	my ( $filename, $inst, $percent) = @_;
	my %idxpos;
	$inst = $data{$inst}-> {file};
	# creating index
	if ( open FF, "> $filename.idx") { 
		my $pos = 0;
		my $lastpos = 0;
		my @order;
		seek $inst, 0, 0;
		while (<$inst>) {
			$lastpos = $pos;
			$pos = tell $inst;
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
		seek $inst, 0, 0;
		my $succeed = 1;
		for ( @order) {
			$succeed = 0, last unless print FF "$_ $idxpos{$_}\n";
		}
		$succeed |= close FF;
		die "Error during creating $filename.idx" unless $succeed;
	} else {
		die "Cannot create index file $filename.idx:$!\n"; 
	}
	$w-> text(( $percent + 25) . '%');


	if ( open FF, "> $filename.ndx") { 
		my @ndxpos;
		my $count = 0;
		my $lastword = '';
		my $lastpos = 0;
		my $pos = 0;
		seek $inst, 0, 0;
		while (<$inst>) {
			$lastpos = $pos;
			$pos = tell $inst;
			next unless /^<b>(?:[XVI]+\.\s)*(.*)<\/b>/;
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
		die "Error during creating $filename.ndx" unless $succeed;
	} else {
		die "Cannot create index file $filename.ndx:$!\n"; 
	}

	$w-> text(( $percent + 50) . '%');
}


sub load_index
{
	return if $noix;
	my ( $filename, $key) = @_;
	my $d = $data{$key};
	my $idxpos = $d-> {idx};
	my $ndxpos = $d-> {ndx};
	if ( open FF, "$path$filename.idx") {
		while (<FF>) {
			chomp;
			next unless /^([\S]+)\s(\d+)(\D*)$/;
			$idxpos-> {$1} = $2;
		}
		close FF;
		if ( scalar( keys %{$idxpos}) < 2)  {
			warning "Index file is not valid, please rebuild index files";
			$noix = 1;
		}
	} else {
		warning "Cannot open $path$filename.idx, please rebuild index files";
		$noix = 1;
	}

	return if $noix;
	if ( open FF, "$path$filename.ndx") {
		my $head = <FF>;
		unless ( $head =~ /ndx count (\d+) div (\d+)/) {
		PROBLEMO:
			warning "Corrupt file $filename.ndx, please rebuild index files";
			$noix = 1;
			return;
		}
		$d-> {count} = $1;
		$d-> {div}   = $2;
		while (<FF>) {
			chomp;
			goto PROBLEMO unless m/^(\d+)$/;
			push @$ndxpos, $1;
		}
		close FF;
		if ( scalar( @$ndxpos) < 2)  {
			warning "Index file is not valid, please rebuild index files";
			$noix = 1;
		}
	} else {
		warning "Cannot open $path$filename.ndx, please rebuild index files";
		$noix = 1;
	}
}

sub index2word
{
	my ( $inst, $index) = @_;
	return '' if $index < 0 || $index >= $inst->{count};
	my $fx = int($index / $inst->{div});
	my $ft = $inst->{ndx}->[ $fx];
	$fx *= $inst->{div};
	my $fff = $inst->{file};

	return $inst->{ncache}->{$fx}->[ $index % $inst->{div}]
		if exists $inst->{ncache}->{$fx};

	$inst->{ncache} = {} if scalar keys %{$inst->{ncache}} > 5;
	
	seek $fff, $ft, 0;

	my $lastword = '';
	$inst->{ncache}->{$fx} = [];
	my $a = $inst->{ncache}->{$fx};
	while ( scalar(@$a) < $inst->{div}) {
		$_ = <$fff>;
		last unless defined;
		chomp;
		next unless /^<b>(?:[XVI]+\.\s)*(.*)<\/b>/;
		next if $1 eq $lastword;
		push ( @$a, $1);
		$lastword = $1;
		$$a[-1] =~ s/\<[^\>]*\>//g;
		$$a[-1] =~ s/\&nbsp;//g;
		$$a[-1] =~ s/\&amp;/\&/g;
	}

	return $$a[ $index % $inst->{div}]  
}

sub index2entry
{
	my ( $inst, $index) = @_;
	return '' if $index < 0 || $index >= $inst->{count};
	my $ft = $inst->{ndx}->[ int($index / $inst->{div})];
	my $fff = $inst->{file};

	seek $fff, $ft, 0;

	my $lastword = '';
	my $data = '';
	my $ix = ($index % $inst-> {div}) + 1;
	my @ret;
	while ( $ix) {
		$_ = <$fff>;
		last unless defined;
		chomp;
		next unless /^<b>(?:[XVI]+\.\s)*(.*)<\/b>/;
		next if $1 eq $lastword;
		$lastword = $1;
		$data = $_;
		$ix--;
	}

	push @ret, $data;

	while ( 1) {
		$_ = <$fff>;
		last unless defined;
		chomp;
		next unless /^<b>(?:[XVI]+\.\s)*(.*)<\/b>/;
		last if $1 ne $lastword;
		push @ret, $_;
	}

	return @ret;
}

sub word2index
{
	my ( $inst, $word) = @_;
	my $lw = length $word;
	return unless $lw;
	$word =~ s/(\/O|\/o)/ø/g;   # O/
	$word =~ s/(\/AE|\/ae)/æ/g; # AE
	$word =~ s/(\/AA|\/aa)/å/g; # A ring
	$word = lc $word;
	$word =~ s/[\`\/\\\'\(\)\.\-\s]*//g;
	
	my $pz;
	if ( $lw > 1) {
		$pz = substr($word,0,2);
		$lw = 1, goto LW_1 unless exists $inst->{idx}->{$pz};
	} else {
LW_1:   
		$pz = substr($word,0,1);
		return unless exists $inst->{idx}->{$pz};
	}

	my $i = @{$inst->{ndx}};
	my $ix = 0;
	while ( $i--) {
		next if $inst->{ndx}->[$i] > $inst->{idx}->{$pz};
		$ix = $i * $inst->{div};
		last;
	}

	my $stage = 0; 
	my $ret = undef;
	my $cmp = 100;
	for ( $i = $ix; $i < $inst->{count}; $i++) {
		my $w = index2word( $inst, $i);
		$w =~ s/[\`\/\\\'\(\)\.\-\s]*//g;
		if ( $stage == 0) {
			if ( $w =~ /^$pz/i) {
				$stage = 1;
				$ret = $i;
				$cmp = length $pz; 
			}
		} else {
			last unless $w =~ /^$pz/i;
		}
		my $qword = quotemeta $word;
		return $i if $w =~ /^$qword/i;
		if ( $stage == 1) {
			my $min = (length($w) > $lw) ? $lw : length($w);
			my $j;
			for ( $j = 1; $j < $min; $j++) {
				next if substr( $w, $j, 1) eq substr( $word, $j, 1);
				$cmp = $j + 1, $ret = $i if $cmp < $j + 1;
				last;
			}
			$cmp = $j, $ret = $i if $j == $min;
		}
	}
	return $ret;
}

sub load_text
{
	my ( $t, $p) = @_;

	$t-> open_read;
	my @ch;
	my $lastpos = 0;
	while ( $p =~ m/(<[^<>]*>)/gcs) {
		push @ch, substr( $p, $lastpos, pos($p)-$lastpos-length($1));
		$lastpos = pos($p);
		my $op = $1;
		$op =~ s/\s*//g;
		push @ch, $op;
	}
	
	my $bigt = '';
	my $txoffs = 0;
	my $ofs = 0;
	my $podmodel = [ 0, $txoffs, 0];;

	my ( $bold, $italic) = (0,0);
	for ( @ch) {
		if ( m/^<(\/?)\s*(.*)\s*>/) {
			if ( lc ($2) eq 'br') {
				$bigt .= "\n";
				$txoffs++;
				$ofs++;
				push @{$t->{model}}, $podmodel;
				$podmodel = [ 0, $txoffs, 0];
				$ofs = 0;
			} else {
				$bold   = ($1 ? 0 : 1) if lc($2) eq 'b';
				$italic = ($1 ? 0 : 1) if lc($2) eq 'i';
				push @$podmodel, tb::fontStyle(
					( $bold   ? fs::Bold   : 0) |
					( $italic ? fs::Italic : 0) 
				);
				push @$podmodel, tb::moveto(0.5, 0, tb::X_DIMENSION_FONT_HEIGHT) if m/<\/i>/;
			}
		} else {
			s{
						\&
						(
							( \d+ )
							| ( [A-Za-z]+ )
						)
						;   
				} {
					do {
							defined $2
							? chr($2)
							:
						defined $Prima::PodView::HTML_Escapes{$3}
							? do { $Prima::PodView::HTML_Escapes{$3} }
							: do { $1; }
					}
				}egx;

			if ( length $_) {
				for ( split '(<br>)', $_) {
					$bigt .= $_;
					push @$podmodel, tb::text( $ofs, length $_);
					$txoffs += length $_;
					$ofs += length $_;
				}
			}
		}
	}
	push @{$t->{model}}, $podmodel;
	$bigt .= "\n";
	$t-> textRef( \$bigt);
	$t-> close_read;
}


sub show_card
{
	my $inst = $_[0];
	my $l = $w-> List-> focusedItem;
	my $word = index2word( $inst, $l);
	my $data = join( "<br><br>", index2entry( $inst, $l));

	$data =~ s/<\!--[^-]*-->//g; # strip comments
	$data =~ s/\&nbsp;/ /g;

	unless ( $card) {
		my $top = $ini-> {CardTop};
		$top = $w-> bottom - 12 if $top =~ /auto/i;
		my $left = $ini-> {CardLeft};
		my @sz = $::application-> size;
		$top = $sz[1] if $top > $sz[1] - 12;
		$top = 12 if $top < 12;
		$left = 0 if $left < 0;
		$left = $sz[0] - 12 if $left + 12 > $sz[0];
		my $ww = Prima::Window-> create( 
			top  => $top,
			left => $left,
			size => [ $ini-> {CardWidth}, $ini-> {CardHeight} ],
			font => $w-> font,
			onDestroy => sub { 
			$ini-> {CardTop}    = $card-> top;
			$ini-> {CardLeft}   = $card-> left;
			$ini-> {CardWidth}  = $card-> width;
			$ini-> {CardHeight} = $card-> height;
			undef $card 
			},
		);


		my $e = $ww-> insert( PodView => 
			origin   => [0,0],
			name     => 'Text',
			size     => [$ww-> size],
			growMode => gm::Client,
			vScroll  => 1,
			hScroll  => 1,
			topicView => 0,
			fontPalette => [ {
				name     => $w-> font-> name,
				encoding => $w-> font-> encoding,
				pitch    => fp::Default,
			} ],
			onKeyDown => sub {
				my ( $self, $code, $key, $mod) = @_;
				$ww-> close if $key == kb::Esc;
			},
			onMouseClick => sub {
				my ( $self, $btn, $mod, $x, $y, $dbl) = @_;
				return unless $dbl;
				$self-> clear_event;
				$lock = 1;
				$x = $self-> info2text_offset( $self-> xy2info( $self-> screen2point( $x, $y)));
				my $lp = reverse substr( ${$self->{text}}, 0, $x);
				my $rp = substr( ${$self->{text}}, $x);
				$lp =~ s/^([^\s\)\(\[\]]*)[\s\)\(\[\]].*$/$1/s;
				$rp =~ s/^([^\s\)\(\[\]]*)[\s\)\(\[\]].*$/$1/s;
				$y = reverse($lp).$rp;
				return unless length $y;
				$self-> selection(  
					$self-> text_offset2info( $x - length $lp),
					$self-> text_offset2info( $x + length $rp));
				language( $card-> {opposite_inst});
				$x = word2index( $data{$current}, $y);
				$w-> List-> focusedItem( $x) if defined $x;
				$lock = 0;
			},
		);
		
		$card = $ww;
	}

	$card-> {opposite_inst} = ( $current eq 'd') ? 'e' : 'd';
	load_text( $card-> Text, $data);
	my $cl = $card-> left;
	$card-> text( $word);
	$w-> select;
	$card-> bring_to_front;
}

sub language
{
	my $lang = $_[0];
	return if $noix;
	return if $lang eq $current;
	my $l = $w-> List;
	$data{$current}-> {ltop} = $l-> topItem;
	$data{$current}-> {lfoc} = $l-> focusedItem;
	$current = $lang; 
	$l-> lock;
	$l-> count(   $data{$current}-> {count});
	$l-> topItem( $data{$current}-> {ltop});
	$l-> focusedItem( $data{$current}-> {lfoc});
	$l-> unlock;
	$w-> Input-> select_all;
	$w-> TabSet-> tabIndex( $data{$current}-> {page});
}


# main

unless ( open FD, "${path}dansk-engelsk.html") {
	warning "Cannot open ${path}dansk-engelsk.html. Reinstall the program";
	exit;
}
binmode FD;
unless ( open FE, "${path}engelsk-dansk.html") {
	warning "Cannot open ${path}engelsk-dansk.html. Reinstall the program";
	exit;
}
binmode FE;
$data{d}->{file} = \*FD;
$data{e}->{file} = \*FE;
load_index( 'dansk-engelsk.html', 'd');
load_index( 'engelsk-dansk.html', 'e');


$w = Prima::Window-> create(
	size => [$ini->{WinWidth},$ini->{WinHeight}],
	name => 'Danish-English dictionary',
	onDestroy => sub {
		( $ini-> {WinWidth}, $ini-> {WinHeight}) = $w-> size;
		$iniFile-> write;
		
		close $data{d}-> {file};
		close $data{e}-> {file};
		$::application-> close;
	},
	onTranslateAccel => sub {
		my ( $self, $code, $key, $mod) = @_;
		$card-> close if $card && $key == kb::Esc;
	},
	font => { 
		map { $_,  $ini->{'Font' . ucfirst($_)}} qw(name size style encoding)
	},
	menuItems => [
		[ "~File" => [
		$noix ? () : (  
			["~Danish-English" => "Ctrl+D" => '^D' => sub { language('d')}],
			["~English-Danish" => "Ctrl+E" => '^E' => sub { language('e')}],
			[],
		),
			["E~xit" => "Alt+X" => '@X' => sub { $::application-> close },],
		]],
		[ "~Options" => [
			["Set ~font" => sub {
				require Prima::FontDialog;
				$fd = Prima::FontDialog-> create unless $fd;
				$fd-> logFont( $w-> font);
				return if $fd-> execute == mb::Cancel;
				my $ret = $fd-> logFont;
				$w-> font( $ret);
				$w-> List-> set(
					itemHeight => $w-> font-> height,
					bottom     => $w-> Input-> top,
					top        => $w-> TabSet-> bottom,
				);
				$card-> font( $ret) if $card;
				$ini-> {'Font' . ucfirst($_)} = $ret-> {$_} for qw(name size style encoding);
				$::application-> hintFont( $ret);
			}],
			[],
			["Rebuild inde~x files" => sub {
				my $ww = $_[0]-> text;
				$_[0]-> text("0%");
				$::application-> pointer( cr::Wait);
				eval { make_index( "${path}engelsk-dansk.html", 'e', 0); };
				warning("$@"), goto RB if $@;
				eval { make_index( "${path}dansk-engelsk.html", 'd', 50); };
				warning("$@"), goto RB if $@;
			RB:   
				$_[0]-> text("$ww");
				$::application-> pointer( cr::Default);
				warning("Please restart the program to make changes visible") unless $@;
			}],
		]],
		[],
		[ "~Help" => [
			["~Usage" => "F1" => "F1" => sub { $::application-> open_help('eddict.pl/USAGE')}],
			["~Copyright" => sub { $::application-> open_help('eddict.pl/COPYRIGHT')}],
			["A~uthor" => sub { $::application-> open_help('eddict.pl/AUTHOR')}],
			[],
			[ "~About" => sub { require Prima::MsgBox; 
				Prima::MsgBox::message( <<ABOUT, mb::OK) }],
Danish-English dictionary, copyright Dmitry Karasik.
See http://www.karasik.eu.org/dict for more information.
Version 1.00.02
ABOUT
		]],
	],
);

$::application-> hintFont( $w-> font);

unless ( $noix) {
	my $dfnx = Prima::TabSet-> profile_default-> {height};
	my $n = $w-> insert( TabSet => 
		ownerFont => 0,
		origin => [-1, $w-> height - $dfnx],
		size   => [ $w-> width + 2, $dfnx],
		tabs   => [ 'Danish', 'English'],
		growMode => gm::Ceiling,
		buffered => 1,
		name     => 'TabSet',
		onChange => sub { language($_[0]-> tabIndex ? 'e' : 'd')},
	);

	$w-> insert( InputLine => 
		origin => [0,0],
		width  => $w-> width,
		text   => '',
		name   => 'Input',
		growMode => gm::Floor,
		onChange => sub {
			return if $lock;
			$lock = 1;
			my $tx = $_[0]-> text;
			$tx = word2index( $data{$current}, $tx);
			$w-> List-> focusedItem( $tx) if defined $tx;
			$lock = 0;
		},
		onKeyDown => sub {
			my ( $self, $code, $key, $mod) = @_;
			if ( scalar grep { $key == $_ } (kb::Up,kb::Down,kb::PgUp,kb::PgDn)) {
				$w-> List-> notify(q(KeyDown), $code, $key, $mod);
				$self-> clear_event;
			}
			if ( $mod & km::Ctrl && (scalar grep { $key == $_ } (kb::Home,kb::End))) {
				$w-> List-> notify(q(KeyDown), $code, $key, $mod & ~km::Ctrl);
				$self-> clear_event;
			}
			if ( $key == kb::Enter) {
				show_card( $data{$current});
				$self-> select_all;
				$self-> clear_event;
			}
		},
	);

	my $l = $w-> insert( AbstractListBox =>
		origin => [0, $w-> Input-> height],
		size   => [ $w-> width, $w-> height - $w-> Input-> height - $w-> TabSet-> height],
		growMode => gm::Client,
		name     => 'List',
		vScroll  => 1,
		integralHeight => 1,
		onStringify => sub {
			my ( $self, $index, $ref) = @_;
			$$ref = index2word( $data{$current}, $index);
		},
		onMeasureItem => sub {
			my ( $self, $index, $ref) = @_;
			$$ref = $self-> get_text_width( index2word( $data{$current}, $index));
		},
		onSelectItem => sub {
			return if $lock;
			$lock = 1;
			$w-> Input-> text( index2word( $data{$current}, $_[0]-> focusedItem));
			$lock = 0;
		},
		onClick => sub {
			show_card( $data{$current});
		},
	);

	$l-> {vScrollBar}-> set(
	autoTrack => 0,
	onTrack => sub {
		$_[0]-> hint( index2word( $data{$current}, $_[0]-> value));
		$_[0]-> hintVisible(1);
	},
	onChange => sub {
		$w-> List-> focusedItem( $_[0]-> value) if $_[0]-> hintVisible;
		$_[0]-> hintVisible(0);
		$_[0]-> hint('');
	},
	);

	$l->count($data{$current}-> {count});

	$l->focusedItem(0);

	$w-> Input-> select;
}

run Prima;

=pod

=head1 COPYRIGHT

The dictionary files, dansk-engelsk.html and engelsk-dansk.html  
are derived from Gyldendals Røde Dansk-Engelsk Ordbog, 9th edition, 
and Gyldendals Røde Engelsk-Dansk Ordbog, 11th edition
and fall under the same copyright as the original dictionary.
The program is and must be distributed WITHOUT the dictionaries.
If you use the dictionary files you should be aware of the following:

=over

=item * 

It is your responsibility to be a valid owner of the
dictionary files. Contact Gyldendal to purchase a license.

=item *

The program creator is not responsible for ANYTHING AT ALL.

=back

The program itself is subject to the following license.

"THE BEER-WARE LICENSE" (Revision 42):

<dmitry@karasik.eu.org> wrote this file.  As long as you retain this notice you
can do whatever you want with this stuff. If we meet some day, and you think
this stuff is worth it, you can buy me a beer in return.   Dmitry Karasik.

=cut
