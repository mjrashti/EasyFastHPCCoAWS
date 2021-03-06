#!/usr/bin/perl
#getNewConfigurationFile.pl

$cfgfile="/home/ec2-user/new_cfg_BestHPCC.sh";
open(CFG,$cfgfile) || die "Can't open for input cfgfile=\"$cfgfile\"\n";
while(<CFG>){
   chomp;
   next if /^#/ || /^\s*$/;
   if ( /^(\w+)=(.+)$/ ){
      my $env_variable=$1;
      my $value=$2;
      push @env_variable, $env_variable;
      eval("\$$env_variable=\"$value\"");
   }
}
close(CFG);

1;
