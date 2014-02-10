#! /usr/bin/perl

#####################################
# mapper.pl
# Chenghao, He
# Feb 2nd, 2014
#####################################

use warnings;
use strict;

my $filename;
my $date;

if(exists $ENV{map_input_file}) {
	$filename = $ENV{map_input_file};
	my @templist = split /\//, $filename;
	my @filedate = split /\-/, $templist[-1];
	$date = $filedate[-2];
	while(<>){
		chomp;
		my @list = split / /;
		if($list[0] eq "en"){
			if($list[1] !~ /^Media:/ && $list[1] !~ /^Special:/ && $list[1] !~ /^Talk:/ && $list[1] !~ /^User:/ && $list[1] !~ /^User_talk:/ && $list[1] !~ /^Project:/ && $list[1] !~ /^Project_talk:/ && $list[1] !~ /^File:/ && $list[1] !~ /^File_talk:/ && $list[1] !~ /^MediaWiki:/ && $list[1] !~ /^MediaWiki_talk:/ && $list[1] !~ /^Template:/ && $list[1] !~ /^Template_talk:/ && $list[1] !~ /^Help:/ && $list[1] !~ /^Help_talk:/ && $list[1] !~ /^Category:/ && $list[1] !~ /^Category_talk:/ && $list[1] !~ /^Portal:/ && $list[1] !~ /^Wikipedia:/ && $list[1] !~ /^Wikipedia_talk:/){
				if($list[1] !~ /\.jpg$/ && $list[1] !~ /\.gif$/ && $list[1] !~ /\.png$/ && $list[1] !~ /\.JPG$/ && $list[1] !~ /\.GIF$/ && $list[1] !~ /\.PNG$/ && $list[1] !~ /\.txt$/ && $list[1] !~ /\.ico$/){
					if($list[1]!~ /^[a-z]/){
						if($list[1] ne "404_error/" && $list[1] ne "Main_Page" && $list[1] ne "Hypertext_Transfer_Protocol" && $list[1] ne "Favicon.ico" && $list[1] ne "Search"){
							print $list[1]."\t".$date.",".$list[2]."\n";
						}
					}
				}
			}
		}
	}
}
else{
	print "No input!\n";
}
