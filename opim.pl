#!/usr/bin/env perl
use warnings;
use strict;
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);
use Cwd qw(getcwd);
use Data::Dumper;
use constant {
	EX_OK => 0,
	EX_USAGE => 64
};

# Globals
my $Restore = undef;
my $Print_Usage_And_Exit = undef;
my $No_Changes = undef;
my $Directory = '.';
my @Ignore = ('.', '..', '.git');
my @Ignore_Extra;
my @Ignore_Replace;
my $Overwrite_If_Exists = undef;
my $File = '.opinfo';


## Shortcut for printing info messages
sub V
{
	print "@_\n";
}

## Read OPI from FS entry; decend to subdirectories when applicable
sub read_fs_entry
{
	my ($path) = @_;
	my ($p, $u, $g) = (stat($path))[2, 4, 5];
	my $r = {};
	$r->{n} = $path;
	$r->{o} = $u .':'. $g;
	$r->{p} = sprintf('0%o', $p & 07777);
	if (-d $path)
	{
		my $orig_cwd = getcwd;
		if (chdir($path))
		{
			if (opendir(my $d, '.'))
			{
				my @children;
				foreach my $entry (readdir($d))
				{
					next if grep {$entry eq $_} @Ignore;
					push(@children, read_fs_entry($entry));
				}
				closedir($d);
				if (@children)
				{
					$r->{c} = [];
					@{$r->{c}} = @children;
				}
			}
			else
			{
				warn $!;
			}
			chdir($orig_cwd);
		}
	}
	return $r;
}

## Recover OPI, traverse subdirectories when applicable
sub recover_opi
{
	my ($dir, $long_dir, $opi, $no_changes)=@_;
	my $orig_cwd = getcwd;
	chdir($dir) or die "Fatal: can't change to $dir: $!";
	foreach my $r (@{$opi->{c}})
	{
		my ($n, $o, $p) = ($r->{n}, $r->{o}, $r->{p});
		my $long_n = $long_dir.'/'.$n;
		$long_n =~ s/\/{2,}/\//g;
		if (-e $n)
		{
			my ($p2, $u, $g) = (stat($n))[2, 4, 5];
			my $o2 = "$u:$g";
			$p2 = sprintf('0%o', $p2 & 07777);
			my $s = '';
			if ($o2 ne $o)
			{
				$s .= "set owners $o2 -> $o: ";
				if ($no_changes)
				{
					$s .= 'skip';
				}
				elsif (chown(split(':', $o), $n) == 1)
				{
					$s .= 'ok';
				}
				else
				{
					$s .= "error: $!";	
				}
			}
			if ($p2 ne $p)
			{
				$s .= '; ' if length($s);
				$s .= "set perms $p2 -> $p: ";
				if ($no_changes)
				{
					$s .= 'skip';
				}
				elsif (chmod(oct($p), $n) == 1)
				{
					$s .= 'ok';
				}
				else
				{
					$s .= "error: $!";	
				}
			}

			V "$long_n: $s" if length($s);
			recover_opi($n, $long_n, $r, $no_changes) if -d $n;
		}
		else
		{
			V "$long_n missing"
		}
	}
	chdir $orig_cwd;
}

sub main
{
	my $rc = GetOptions(
		'R'   => \$Restore,
		'h'   => \$Print_Usage_And_Exit,
		'd=s' => \$Directory,
		'f=s' => \$File,
		'o'   => \$Overwrite_If_Exists,
		'i=s' => \@Ignore_Extra,
		'x=s' => \@Ignore_Replace,
		'n'   => \$No_Changes
	);

	
	pod2usage(EX_USAGE) if not $rc;
	pod2usage(EX_OK) if $Print_Usage_And_Exit;
	if (@Ignore_Replace)
	{
		@Ignore = ('.', '..', @Ignore_Replace);
	}
	if (@Ignore_Extra)
	{
	    push(@Ignore, @Ignore_Extra);
	}

	if ($Restore)
	{
		open(my $f, $File) or die "Fatal: can't read '$File': $!";
		my $r;
		{
			local $/ = undef;
			my $data = <$f>;
			$r = eval $data or die<<EOF
Fatal: failed to evaluate data from file:
$@
Data:
$data
EOF
		}
		close($f);
		recover_opi($Directory, $Directory, $r, $No_Changes);
	}
	else
	{
		my $r = read_fs_entry($Directory);
		delete $r->{n};
		delete $r->{p};
		delete $r->{o};
		if (-e $File and not $Overwrite_If_Exists)
		{
			die <<EOF;
OPI '$File' exists.
Use '-o' to overwrite or set different output file with '-f'.
EOF
		}
		local $Data::Dumper::Terse = 1;
		local $Data::Dumper::Indent = undef;
		local $Data::Dumper::Quotekeys = undef;
		open(my $f, ">$File") or die "Fatal: can't write to '$File': $!";
		print $f Dumper($r);
		close($f);
	}
}

main;

__END__
=pod

=head1 NAME

opim.pl - ownership and permissions info (OPI) maintenance tool

=head1 SYNOPSIS

Collect OPI from filesystem and save to file:

=over

=item

opim.pl [-{i|x} ignore_pattern] [-d directory] [-o] [-f file]

=back

Restore OPI from file to target directory:

=over

=item

opim.pl -R [-n] [-f file] [-d directory]

=back

=head2 Common options:

-d directory to read OPI from or restore to.
   Default is current directory.

-f file to store OPI to or read from.
   Default is '.opinfo'

=head2 Options affecting collection of OPI:

-i add pattern to ignore.
   Can be used multiple times.
   Default is to ignore '.git'.

-x replace default ignore patterns with given.
   Can be used multiple times.

-o overwrite OPI file if it exists.

=head2 Options affecting OPI restore:

-n make no changes, just print what supposed to be done.

=head1 DESCRIPTION

Tracking files with Git (or other VCS) doesn't have native provision for storing
and recovering ownership and permissions info (OPI).

opim.pl helps to fill this gap.

First you run opim.pl to collect OPI from filesystem and save it to file.

When deploying files back to filesystem from repository, you run opim.pl again
to read saved OPI from file and restore it to deployed files providing same
ownership and permissions as were in the original filesystem.

=head1 LICENSE

The FreeBSD License

Copyright (c) 2021, Valerii Valeev.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

=over

=item 1

Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

=item 2

Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

=back

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=head1 AUTHOR

Valerii Valeev <valerii.valeev@mail.ru>
