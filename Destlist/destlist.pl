#! c:\perl\bin\perl.exe
#-----------------------------------------------------------
# Version: 20151129
#
#	Original Author: Harlan Carvey
#	Updates Author: Phillip Moore, randomaccess3@gmail.com	
#

# There appears to be a bug in the jumplist.pm code when dealing with some jumplists 
# (the code starting line 387 of jumplist.pm; and/or loading up the right information into the SSAT, I'm not sure yet)
# The relevant destlist parsing code does however work if the stream is provided directly
# I've copied out the relevant routines from jumplist.pm and they appear below

# This is a simple script to demonstrate the use of the JumpList.pm
# module; outputs in .csv and TLN output
#
# Author: H. Carvey, keydet89@yahoo.com
# copyright 2011-2012 Quantum Research Analytics, LLC
#-----------------------------------------------------------
use strict;

my $version = "20151129";

use Getopt::Long;
my %config = ();
Getopt::Long::Configure("prefix_pattern=(-|\/)");
GetOptions(\%config, qw(dir|d=s file|f=s server|s=s user|u=s tln|t csv|c help|?|h));

if ($config{help} || ! %config) {
	_syntax();
	exit 1;
}

my $server;
($config{server}) ? ($server = $config{server}) : ($server = "");

my $file = $config{file};
my %hash;

%hash = ();
	
my %dl = ();
my $stream;
open(FH,"<",$file);
binmode(FH);
my $size = (stat($file))[7];
seek(FH,0,0);
read(FH,$stream,$size);
#print "parse destlist stream\n";
%dl = parse_destlist_stream($stream);
	
foreach my $k (keys %dl) {
	my $t = $dl{$k}{position};
	my $mru = $dl{$k}{mrutime};
#	my $str = $jl->getStream($k);
#	next if (length($str) < 0x4C);
	push(@{$hash{$mru}},$dl{$k}{str});
}

if ($config{csv}) {
	foreach my $link (reverse sort {$a <=> $b} keys %dl){
		my $mrutime = $dl{$link}{mrutime};
		print gmtime($mrutime).", ".$dl{$link}{str}."\n"; #this is sorted by the stream rather than the mrutime
	}
}
elsif ($config{tln}) {
	foreach my $link (reverse sort {$a <=> $b} keys %dl){
		my $mrutime = $dl{$link}{mrutime};
		my $data = $dl{$link}{str};
		my $tln8_comment = "";
		print $mrutime."|JumpList|".$config{server}."|".$config{user}."|DESTLIST File Access-".$data."\n" if ($mrutime != 0);
	}
}
else {
	foreach my $link (sort keys %dl){
		print "Item: $dl{$link}{str}\n";
		print "mrutime: $dl{$link}{mrutime}\n";
			
			#foreach my $i (0..(scalar(keys %vals) - 1)) {
			#	if (exists $dl{$link}{$vals{$i}}) {
			#		print $vals{$i}.": ".$dl{$link}{$vals{$i}}."\n";
			#	}
			#}
			#print "\n";
	}
}	
	
#foreach my $t (reverse sort {$a <=> $b} keys %hash) {
#	print gmtime($t).",";
#	foreach my $i (@{$hash{$t}}) {
#		print "  ".$i."\n";
#	}
#}
#print "\n";  


sub _syntax {
print<< "EOT";
destlist [option]
Parse Destlist stream

  -f file........parse a single DestList stream
  -c ............Comma-separated (.csv) output (open in Excel)
  -t ............output in TLN format   
  -s server......add name of server to TLN ouput (use with -t)  
  -u user........add username to TLN output (use with -t)         
  -h ............Help (print this information)
  
Ex: C:\\>destlist -f Destlist.stream -t

**All times printed as GMT/UTC

copyright 2012 Quantum Analytics Research, LLC
EOT
}   



#=============================================================================
# Code from Jumplist.pm
#=============================================================================


sub parse_destlist_stream {
	my $stream = shift;
	my %destlist;
	
	
	my @num = unpack("VV",substr($stream,4,8));
	my @num2 = unpack("VV",substr($stream,24,8));
#if ($num[1] == 0) {
#	print "Number of entries = ".$num[0]."\n";
#}
#print "Valid header.\n" if ($num2[0] == $num[0] && $num2[1] == $num[1]);

# Start reading the first "object" or structure
	my $offset = 0x20;
	foreach (1..$num[0]) {
		my $str_sz = unpack("v",substr($stream,$offset + 112,2));

# Total structure size = 112 + 2 + ($str_sz * 2) bytes
		my $sz = 112 + 2 + ($str_sz * 2);
		my $data = substr($stream, $offset, $sz);
		my %st = parse_destlist_struct($data);
		
		$destlist{$st{position}}{mrutime} = $st{mrutime};
		$destlist{$st{position}}{str}     = $st{str};
		$destlist{$st{position}}{uname}   = $st{uname};
		$offset += $sz;
	}
	return %destlist;
}

sub parse_destlist_struct {
	my $data = shift;
	my %struct;
	
#	$struct{t1} = getTime(unpack("VV",substr($data,24,8))); 
#	$struct{t2} = getTime(unpack("VV",substr($data,56,8)));
	my @t = unpack("VV",substr($data,100,8));
	$struct{mrutime} = getTime($t[0],$t[1]);
	$struct{uname} = substr($data,72,16);
	$struct{uname} =~ s/\00//g;
	
	my @mark = unpack("VV",substr($data,88,8));
	if ($mark[1] == 0) {
		$struct{position} = sprintf "%x",$mark[0];
	}
	
	my $sz = unpack("v",substr($data,112,2));
	$struct{str} = substr($data,114,($sz * 2));
	$struct{str} =~ s/\00//g;
	return %struct;
}

sub getTime($$) {
	my $lo = shift;
	my $hi = shift;
	my $t;

	if ($lo == 0 && $hi == 0) {
		$t = 0;
	} else {
		$lo -= 0xd53e8000;
		$hi -= 0x019db1de;
		$t = int($hi*429.4967296 + $lo/1e7);
	};
	$t = 0 if ($t < 0);
	return $t;
}


