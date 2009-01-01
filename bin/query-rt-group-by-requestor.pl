# see first posting http://use.perl.org/~LaPerla/journal/35252
# (Top rt.cpan.org requestors) (up to ticket 32022)

# second: http://use.perl.org/~LaPerla/journal/38195 (Who wrote all
# the RT tickets?) (up to ticket 42061)

=pod

RT::Client::REST broke at some point in time and I posted a mostly
clueless patch that seemed to work. At least the progam did not die
immediately. The patch was integrated into 0.35 and soon after that
ticket 35146 was opened that reverted a part of my patch. (Sidenote:
The patch is posted reverse)

Now with that patch this program again died quickly with

    HTTP::Message content must be bytes

So I decided to patch REST thusly:

--- /home/k/.cpan/build/RT-Client-REST-0.35-d_Mo_f/lib/RT/Client/REST.pm	2008-04-15 12:24:11.000000000 +0200
+++ /home/src/perl/repoperls/installed-perls/perl/pVNtS9N/perl-5.8.0@32642/lib/site_perl/5.10.0/RT/Client/REST.pm	2008-05-01 09:27:13.000000000 +0200
@@ -496,7 +496,8 @@
         # not sufficiently portable and uncomplicated.)
         $res->code($1);
         $res->message($2);
-        $res->decoded_content($text);
+        use Encode;
+        $res->content(Encode::encode_utf8($text));
         #$session->update($res) if ($res->is_success || $res->code != 401);
         if ($res->header('set-cookie')) {
             my $jar = HTTP::Cookies->new;




Of course this cannot be correct but for me it works right now quite
well but only because rt.cpan.org sends charset=utf-8 or so.

=cut

use strict;
use warnings;

use RT::Client::REST;
use Getopt::Long;
use List::Util qw(max);
use YAML::Syck;

warn "Working with version $RT::Client::REST::VERSION";

# XXX yes, it's a stupid setup that requires an argument to
# (logically) boolean options
my %Config = (
              server      => 'https://rt.cpan.org',
              username    => 'ANDK',
              password    => '',
              chunksize   => 396,
              html        => 0,
              top         => 40,
              withlastyear => 0, # well, hardcoded 2007
              upto        => 0,  # allows recalc against a point in the past
             );

GetOptions(\my %config, map { "$_=s" } keys %Config) or die;
while (my($k,$v) = each %config) {
  $Config{$k} = $v;
}

my $yaml_db_file = "$ENV{HOME}/sources/CPAN/data/query-rt-group-by-requestor.yml";
my $ALL;
if (-e $yaml_db_file) {
  $ALL = YAML::Syck::LoadFile($yaml_db_file);
} else {
  warn "WARNING: yaml file '$yaml_db_file' not found!!!";
  sleep 3;
  $ALL = {};
}
my $curmax = max keys %{$ALL->{tickets} || {}};
$curmax ||= 0;
print "highest registered ticket number ATM: $curmax\n";
$curmax ||= 1;
FINDHOLES: for (my $i = 1; $i <= $curmax; $i++) {
  if (exists $ALL->{tickets}{$i}) {
  } else {
    $curmax = $i;
    last FINDHOLES;
  }
}
print "Max after findholes: $curmax\n";
TRIM: for (my $i = $curmax;;$i--) {
    my $ticket = $ALL->{tickets}{$i};
    $curmax = $i;
    if (keys %$ticket) {
        last;
    } else {
        delete $ALL->{tickets}{$i};
    }
}
print "Max after trim: $curmax\n";

my $nextmax = $curmax + $Config{chunksize};

my $rt = RT::Client::REST->new(
                               server  => $Config{server},
                               timeout => 300
                              );

if ($Config{password}) {
  eval { $rt->login( username => $Config{username}, password => $Config{password} ); };
  die "Alert: Problem logging in: '$@'" if $@;

  my @ids;
  eval {
    @ids = $rt->search(
                       type    => 'ticket',
                       query   => qq[(Id >= $curmax and Id <= $nextmax)],
                      );
  };
  die "search failed: $@" if $@;

  my %ids;
  @ids{@ids} = ();
  $|=1;
  my $maxid = max @ids;
  print "filling $curmax..$maxid\n";
 ID: for my $id ($curmax..$maxid) {
    my $feedback;
    if ($ALL->{tickets}{$id}){
      $feedback = "E"; # existed before
    } else {
      if (exists $ids{$id}) {
      } elsif (keys %ids) {
      } else {
        print "\nStopping at $id.\n";
        last ID;
      }
      my $ticket = exists $ids{$id} ? $rt->show(type => 'ticket', id => $id) : {};
      if (keys %$ticket) {
        $feedback = "w"; # wrote something interesting
      } else {
        $feedback = "e"; # empty
      }
      $ALL->{tickets}{$id} = $ticket;
    }
    print $feedback;
    delete $ids{$id};
    unless ($id % 17){
      print "z";
      sleep 3;
    }
  }
  YAML::Syck::DumpFile("$yaml_db_file.new", $ALL);
  rename "$yaml_db_file.new", $yaml_db_file;
  print "filled\n";
}

sub who {
  my($v) = @_;
  my $who = $v->{Requestors} || $v->{Creator};
  return "" unless $who;
  if ($who =~ s/\@cpan\.org(,.*)?$//) {
    $who = uc $who;
  }
  my %alias = (
               'ANDY@PETDANCE.COM, ESUMMERS' => 'PETDANCE',
               'Marek.Rouchal@gmx.net'      => 'MAREKR',
               'marek.rouchal@infineon.com' => 'MAREKR',
               'aaron@FreeBSD.org'          => 'ACDALTON',
               'agentzh@gmail.com'          => 'AGENT',
               'alexchorny@gmail.com'       => 'CHORNY',
               'andreas.koenig@anima.de'    => 'ANDK',
               'andy@petdance.com'          => 'PETDANCE',
               'a.r.ferreira@gmail.com'     => 'FERREIRA',
               'ask@develooper.com'         => 'ABH',
               'at@altlinux.org'            => 'ATOURBIN',
               'at@altlinux.ru'             => 'ATOURBIN',
               'audreyt@audreyt.org'        => 'AUDREYT',
               'autrijus@autrijus.org'      => 'AUDREYT',
               'barbie@missbarbell.co.uk'   => 'BARBIE',
               'blair@orcaware.com'         => 'BZAJAC',
               'chris@clotho.com'           => 'CLOTHO',
               'corion@corion.net'          => 'CORION',
               'cpan@ali.as'                => 'ADAMK',
               'cpan@audreyt.org'           => 'AUDREYT',
               'cpan@chrisdolan.net'        => 'CDOLAN',
               'cpan@clotho.com'            => 'CLOTHO',
               'cpan@pjedwards.co.uk'       => 'STIGPJE',
               'dan.horne@redbone.co.nz'    => 'DHORNE',
               'david@landgren.net'         => 'DLAND',
               'dha@panix.com'              => 'DHA',
               'gbarr@pobox.com'            => 'GBARR',
               'he@NetBSD.org'              => 'Havard Eidnes',
               'imacat@mail.imacat.idv.tw'  => 'IMACAT',
               'ivorw-cpan@xemaps.com'      => 'IVORW',
               'jdhedden@1979.usna.com'     => 'JDHEDDEN',
               'jesse@bestpractical.com'    => 'JESSE',
               'jesse@fsck.com'             => 'JESSE',
               'jhi@iki.fi'                 => 'JHI',
               'julian@mehnle.net'          => 'JMEHNLE',
               'mark@summersault.com'       => 'MARKSTOS',
               'mark@twoshortplanks.com'    => 'MARKF',
               'merlyn@stonehenge.com'      => 'MERLYN',
               'mnodine@alum.mit.edu'       => 'NODINE',
               'm.nooning@comcast.net'      => 'MNOONING',
               'mstevens@etla.org'          => 'MSTEVENS',
               'nadim@khemir.net'           => 'NKH',
               'nigel.metheringham@Dev.intechnology.co.uk' => 'NIGELM',
               'njh@bandsman.co.uk'         => 'NJH',
               'njh@ecs.soton.ac.uk'        => 'NJH',
               'nospam-abuse@bloodgate.com' => 'TELS',
               'ntyni@iki.fi'               => 'Niko Tyni',
               'nothingmuch@woobling.org'   => 'NUFFIN',
               'rafl@debian.org'            => 'FLORA',
               'rcaputo@pobox.com'          => 'RCAPUTO',
               'ron@savage.net.au'          => 'RSAVAGE',
               'rurban@x-ray.at'            => 'RURBAN',
               'shlomif@iglu.org.il'        => 'SHLOMIF',
               'schmorp@schmorp.de'         => 'MLEHMANN',
               'schwern@pobox.com'          => 'MSCHWERN',
               'schwern@bestpractical.com'  => 'MSCHWERN',
               'slaven@rezic.de'            => 'SREZIC',
               'slaven@cpan'                => 'SREZIC',
               'slaven.rezic@berlin.de'     => 'SREZIC',
               'steve.hay@uk.radan.com'     => 'SHAY',
               'steve@fisharerojo.org'      => 'SMPETERS',
               'steven@knowmad.com'         => 'WMCKEE',
               'stro@railways.dp.ua'        => 'STRO',
               'user42@zip.com.au',         => 'KRYDE',
               'ville.skytta@iki.fi'        => 'SCOP',
               'william@knowmad.com'        => 'WMCKEE',
               'xdaveg@gmail.com'           => 'DAGOLDEN',
              );
  $who = $alias{$who} || $who;
}

sub users_2007 {
  my $postedlist = <<'EOL';
     1: guest      486
     2: SREZIC     393
     3: MSCHWERN   385
     4: ANDK       347
     5: ADAMK      317
     6: MARKSTOS   304
     7: CHORNY     248
     8: RRWO       205
     9: WMCKEE     161
    10: SMPETERS   136
    11: TONYC      132
    12: LGODDARD   129
    13: CDOLAN     117
    14: JDHEDDEN   114
    15: RCAPUTO    110
    16: RJBS       101
    17: MAREKR     101
    18: MTHURN      98
    19: ATOURBIN    85
    20: PETDANCE    84
    21: SAPER       79
    22: BARBIE      72
    23: JESSE       71
    24: NKH         62
    25: IMACAT      60
    26: CORION      60
    27: ACDALTON    59
    28: DAGOLDEN    58
    29: CLOTHO      57
    30: RSAVAGE     57
    31: MERLYN      52
    32: HANENKAMP   51
    33: Niko Tyni   51
    34: TELS        49
    35: LTHEGLER    47
    36: MARKF       47
    37: PODMASTER   47
    38: JPIERCE     47
    39: GROUSSE     46
    40: BZAJAC      46
    41: KANE        44
    42: JONASBN     44
    43: STENNIE     43
    44: SPOON       43
    45: MUENALAN    41
    46: JJORE       41
    47: RURBAN      40
    48: SHLOMIF     37
    49: JOHANL      36
    50: dsteinbrunner@pobox.com   36
    51: SHAY        36
    52: DLAND       36
    53: IVORW       35
    54: mcummings@gentoo.org   34
    55: FERREIRA    34
    56: NUFFIN      34
    57: NIKC        33
    58: STIGPJE     33
    59: arnaud@underlands.org   33
    60: MSTEVENS    32
    61: DHA         31
    62: ABH         31
    63: NJH         31
    64: SCOP        30
    65: KWILLIAMS   30
    66: STRO        30
    67: SMYLERS     30
    68: perl@infotrope.net   29
    69: DHORNE      29
    70: dave@riverside-cms.co.uk   28
    71: SMUELLER    28
    72: dhoworth@mrc-lmb.cam.ac.uk   27
    73: ISHIGAKI    27
    74: JKEENAN     26
    75: JMEHNLE     26
    76: DMUEY       26
    77: tom@eborcom.com   25
    78: cpan@fireartist.com   25
    79: JROCKWAY    25
    80: NODINE      25
    81: DMITRI      24
    82: JHI         24
    83: RENEEB      24
    84: jpo@di.uminho.pt   24
    85: DOM         24
    86: cweyl@alumni.drew.edu   24
    87: BOOK        23
    88: OVID        23
    89: DAXIM       22
    90: tony@develop-help.com   22
    91: THALJEF     22
    92: CNANDOR     21
    93: GHENRY      21
    94: CLACO       21
    95: perl@crystalflame.net   21
    96: YANICK      21
    97: m.romani@spinsoft.it   21
    98: MARKOV      20
    99: DJERIUS     20
    100: LEIRA       20
EOL

  my %p;
  for my $line (split /\n/, $postedlist) {
    my($pos,$name,$count) = $line =~ /(\d+):\s(\S.+\S)\s+(\d+)$/;
    $p{$name} = { pos => $pos, count => $count };
  }
  return \%p;
}

keys %{$ALL->{tickets}}; # reset iterator
my %S;
TICKET: while (my($k,$v) = each %{$ALL->{tickets}}) {
  if (my $upto = $Config{upto}) {
    next TICKET if $k > $upto;
  }
  my $who = who($v);
  next TICKET unless $who;
  $S{$who}++;
}
my $top = 1;
printf "%s\n", $Config{html} ? "<dl>" : "";
my $p;
my $sprintf = "%s%2d: %-9s %4d%s\n";
if ($Config{withlastyear}) {
  $sprintf = "%s%2d: %-9s %4d (%2s) %3s%s\n";
  $p = users_2007();
}
for my $k (sort {$S{$b} <=> $S{$a}} keys %S) {
  my $x = sprintf
      (
       $sprintf,
       $Config{html} ? "<code>" : " ",
       $top,
       $k,
       $S{$k},
       $p ? ( $p->{$k}{pos} || "-", $p->{$k}{pos} ? $S{$k}-$p->{$k}{count} : "-") : (),
       $Config{html} ? "</code><br/>" : "",
      );
  $x =~ s/ /&nbsp;/g if $Config{html};
  print $x;
  my $showtop = $Config{top} || 40;
  last if $top >= $showtop;
  $top++;
}
printf "%s\n", $Config{html} ? "</dl>" : "";

# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:
