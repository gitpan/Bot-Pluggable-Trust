package Bot::Pluggable::Trust;
$VERSION = 0.06;
use strict;
use warnings;
use base qw(Bot::Pluggable::Common);

=pod

=head1 NAME

Bot::Pluggable::Trust - A Trust Module for Bot::Pluggable

=head1 SYNOPSIS

my $trust = new Bot::Pluggable::Trust(
    owner=>"perigrin",
    delay => 5,
    lag => 20,
    DEBUG=>1,
);

=head1 DESCRIPTION

A simple Slavorg style Trust module, designed to replace the Mozbot
Trust module employed by Marvin (a mozbot) on #axkit, and #axkit-dahut

Much of this code was 'Borrowed' from the Slavorg2 PoCo::IRC bot
found at L<http://jerakeen.org/cms/slavorg2> and converted over to
Bot::Pluggable despite the issues brought up on
L<http://www.jerakeen.org/cms/irc/bots>
(which since he wrote Bot::BasicBot::Pluggable really don't stand for much do they?)

=cut

use POE;

sub new {
        my $class = shift;
        my %args = @_;
        return bless \%args, $class
}

######################################################################################
## Utils
######################################################################################

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    for my $event qw(irc_353 dotheopthing) {
        $self->{_BOT_}->add_event($event);
    }
    $self->load();
}

sub load {
    my ($self) = @_;
    for my $channel (keys %{ $self->channels }) {
        print STDERR"Loading Ops\n" if $self->{DEBUG};
        $self->load_ops(lc($channel));
        print STDERR "Loading Voice\n" if $self->{DEBUG};
        $self->load_voice(lc($channel));
    }
}

sub save {
    my $self = shift;
    print STDERR "save\n" if $self->{DEBUG};
    for my $channel (keys %{ $self->channels }) {
        print STDERR "Saving Ops\n" if $self->{DEBUG};
        $self->save_ops(lc($channel));
        print STDERR "Saving Voice\n" if $self->{DEBUG};
        $self->save_voice(lc($channel));
    }
}

sub load_ops {
    my ($self, $channel) = @_;
    my $channels = $self->channels;
    $channels->{$channel}->{ops} = {};
         my $file = "$self->{_BOT_}->{Nick}_ops";
    if (open(READ, "$file")) {
        while (<READ>) {
            chomp;
            $channels->{$channel}{ops}{$_}++ unless $channels->{$channel}{ops}{$_};
        }
        close(READ);
    } else {
        print STDERR "Can't open ops file ($file): $!\n";
    }
    $self->channels($channels);
}

sub load_voice {
    my ($self, $channel) = @_;
    my $channels = $self->channels;
    $channels->{$channel}->{voice} = {};
         my $file = "$self->{_BOT_}->{Nick}_voice";
    if (open(READ, "$file")) {
        while (<READ>) {
            chomp;
            $channels->{$channel}{voice}{$_}++ unless $channels->{$channel}{voice}{$_};
        }
        close(READ);
    } else {
        print STDERR "Can't open voice file ($file): $!\n";
    }
    $self->channels($channels);
}

sub save_ops {
    my ($self, $channel) = @_;
    my $channels = $self->channels;
    my $file = "$self->{_BOT_}->{Nick}_ops";
    if (open(READ, ">$file")) {
        print READ "$_\n" for keys(%{$channels->{$channel}{ops}});
        close READ;
    } else {
        print STDERR "Can't save ops file ($file): $!\n";
    }
    $self->channels($channels);
}

sub save_voice {
    my ($self, $channel) = @_;
    my $channels = $self->channels;
    my $file = "$self->{_BOT_}->{Nick}_voice";
    if (open(READ, ">")) {
        print READ "$_\n" for keys(%{$channels->{$channel}{voice}});
        close READ;
    } else {
        print STDERR "Can't save voice file ($file): $!\n";
    }
    $self->channels($channels);
}

sub add_op {
    my ($self, $target, $channel) = @_;
    print STDERR "add_op $target $channel\n" if $self->{DEBUG};
    my $channels = $self->channels;
    $channels->{$channel}{ops}{$target}++;
    delete $channels->{$channel}{voice}{$target} if $channels->{$channel}{voice}{$target};
    $self->channels($channels);
    $self->save();
}

sub remove_op {
    my ($self, $target, $channel) = @_;
    print STDERR "remove_op $target $channel\n" if $self->{DEBUG};
    my $channels = $self->channels;
    delete $channels->{$channel}{ops}{$target};
    delete $channels->{$channel}{voice}{$target} if $channels->{$channel}{voice}{$target};
    $self->channels($channels);
    $self->save();
}

sub add_voice {
    my ($self, $target, $channel) = @_;
    print STDERR "add_voice $target $channel\n" if $self->{DEBUG};
    my $channels = $self->channels;
    $channels->{$channel}{voice}{$target}++;
    $self->channels($channels);
    $self->save();
}

sub remove_voice {
    my ($self, $target, $channel) = @_;
    print STDERR "remove_voice $target $channel\n" if $self->{DEBUG};
    my $channels = $self->channels;
    delete $channels->{$channel}{voice}{$target};
    $self->channels($channels);
    $self->save();
}

sub check_ops {
    my ($self, $nick, $channel) = @_;
    return 1 if ($nick eq $self->{owner}); #Bawhahaha!
    if ($channel) {
        return $self->channels->{$channel}{ops}{$nick};
    }
    else {
        for $channel (keys %{ $self->channels }) {
            return 1 if $self->channels->{$channel}{ops}{$nick};
        }
    }
}

sub check_voice {
    my ($self, $nick, $channel) = @_;
    if ($channel) {
         return $self->channels->{$channel}{voice}{$nick};
    } else {
         for $channel (keys %{ $self->channels }) {
                 return 1 if $self->channels->{$channel}{voice}{$nick};
         }
    }
}

sub list_ops {
    my $self = shift;
    my %ops = ();
    for my $channel (keys %{ $self->channels }) {
        for my $user (keys %{ $self->channels->{$channel}{ops} }) {
            $ops{$user}++
        }
    }
    return [$$self{owner}, keys %ops];
}

sub reset_opq {
    my ($self, @channels) = @_;
    for my $channel (@channels) {
        delete $self->{$channel}{to_op};
        delete $self->{$channel}{to_voice};
        $self->{_BOT_}{recent_names} = time && $self->names($channel) # reset the names list
              unless (time - ( $self->{_BOT_}{recent_names} || 0 ) < $self->{lag});  # Unless we've asked for names recently....
    }
    $poe_kernel->delay_set("dotheopthing", $$self{delay} || 10);
}

sub trust {
    my ($self, $channel, $target, $nick) = @_;
    if ($self->check_ops($target, $channel)) {
        return "But I already trust $target in $channel";
    } elsif (!($self->check_ops($nick, $channel))) {
        return "But I don't trust >you< in $channel, $nick";
    } elsif (!$channel) {
        return "Uh, you need to tell me that again in a channel, or be more explicit about where.";
    } else {
        eval {
            print STDERR "Trusting '$target' due to '$nick'\n" if $self->{DEBUG};
            $self->add_op($target, $channel);
            $self->reset_opq($channel);
        };
        if ($@) {
            warn "there was a problem: $@";
            return "I seem to be having trouble doing that";
        }
        return "OK, $nick";
    }
}

sub believe {
    my ($self, $channel, $target, $nick) = @_;
    if ($self->check_voice($target, $channel)) {
        return "But I already believe $target";
    } elsif ($self->check_ops($target, $channel)) {
        return "But I already >trust< $target in $channel";
    } elsif (!($self->check_ops($nick, $channel))) {
        return "But I don't trust >you< in $channel, $nick";
    } elsif (!$channel) {
        return "Uh, you need to tell me that again in a channel, or be more explicit about where.";
    } else {
        eval {
            print STDERR "Voicing '$target' due to '$nick'\n" if $self->{DEBUG};
            $self->add_voice($target, $channel);
            $self->reset_opq($channel);
        };
        if ($@) {
            warn "there was a problem: $@";
            return "I seem to be having trouble doing that";
        }
        return "OK, $nick"
    }
}

sub distrust {
    my ($self, $channel, $target, $nick) = @_;
    if (!($self->check_ops($target, $channel))) {
        return "But I don't trust $target";
    } elsif (!($self->check_ops($nick, $channel))) {
        return "But I don't trust >you<, $nick";
    } elsif ($self->{owner} eq $target) {
        print STDERR "$nick tried to distrust $$self{owner}. Telling him to fuck right off.\n" if $self->{DEBUG};
        return "Yeah, right. As if.";
    } elsif (!$channel) {
        return "Uh, you need to tell me that again in a channel. Or be more explicit about where.";
    } else {
        eval {
            print STDERR "Distrusting '$target' due to '$nick'\n" if $self->{DEBUG};
            $self->remove_op($target, $channel);
        };
        if ($@) {
            warn "there was a problem: $@";
            return "I seem to be having trouble doing that";
        }
        return "Ok, $nick"
    }
}

sub disbelieve {
    my ($self, $channel, $target, $nick) = @_;
    if (!($self->check_voice($target, $channel))) {
        return "But I don't believe $target in $channel";
    } elsif ($self->check_ops($target, $channel)) {
        return "But I >trust< $target in $channel";
    } elsif (!($self->check_ops($nick, $channel))) {
        return "But I don't trust >you< in $channel, $nick";
    } elsif (!$channel) {
        return "Uh, you need to tell me that again in a channel, or be more explicit about where.";
    } else {
        eval {
            print STDERR "De-voicing '$target' due to '$nick'\n" if $self->{DEBUG};
            $self->remove_voice($target);
        };
        if ($@) {
            warn "there was a problem: $@";
            return "I seem to be having trouble doing that";
        }
        return "Ok, $nick";
    }
}

sub check_trust {
    my ($self, $channel, $target, $nick) = @_;
    if ($self->check_ops($target)) {
        return "Yes, I trust $target.";
    } else {
        return "No, I don't trust $target.";
    }
}

sub trust_where {
        my ($self, $channel, $target) = @_;
        my @rooms = ();
   if ($target eq $$self{owner}) {
        @rooms = keys %{ $self->channels };
   }
   else {
        my $channels = $self->channels();
        for my $channel (keys %$channels) {
        push @rooms, $channel if $channels->{$channel}{ops}{$target};
        }
   }
    return "I trust $target in ". CORE::join(', ', @rooms) if ($rooms[0]);
        return "I don't trust $target anywhere";
}

sub check_belief {
    my ($self, $channel, $target, $nick) = @_;
    if ($self->check_voice($target) || $self->check_ops($target)) {
        return "Yes, I believe $1.";
    } else {
        return "No, I don't believe $1.";
    }
}

sub believe_where {
        my ($self, $channel, $target) = @_;
        my %rooms = ();
    if ($target eq $$self{owner}) {
        for (keys %{ $self->channels() }) {
            $rooms{$_}++;
        }
    }
    else {
        my $channels = $self->channels();
        for my $channel (keys %$channels) {
            $rooms{$channel}++ if $channels->{$channel}{ops}{$target};
            $rooms{$channel}++ if $channels->{$channel}{voice}{$target};
        }
    }
    return "I believe $target in ". CORE::join(', ', keys %rooms) if (keys %rooms);
        return "I don't trust $target anywhere";
}

sub told {
    my ($self, $nick, $channel, $message) = @_;
    my $sender = $channel || $nick;
    my $PUNC_RX = qr([?.!]?);
    my $NICK_RX = qr([][a-z0-9^`{}_|\][a-z0-9^`{}_|\-]*)i;
    my $CHAN_RX = qr(#$NICK_RX)i;
    my $commands = qr(trust|distrust|believe|disbelieve);
    # Trust
    if ($message =~ /^($commands)\s+($NICK_RX)\s*(?:in\s+($CHAN_RX))?$/i) {
        my ($command, $target, $channel) = ($1, $2, ($3 || $channel));
        my $res = $self->$command(lc($channel), $target, $nick);
        return $self->tell($sender, $res);
    }
    # Check Trust
    elsif ($message =~ /^do\s+you\s+trust\s+($NICK_RX)$PUNC_RX/i) {
        my $target = $1;
        my $res = $self->check_trust(lc($channel), $target, $nick);
        return $self->tell($sender, $res);
    }
    # Locate Trust
    elsif ($message =~ /^where\s+do\s+you\s+trust\s+($NICK_RX)$PUNC_RX/i) {
        my $target = $1;
        my $res = $self->trust_where(lc($channel), $target, $nick);
        return $self->tell($sender, $res);
    }
    # Check Belief
    elsif ($message =~ /^do\s+you\s+believe\s+($NICK_RX)$PUNC_RX/i) {
        my $target = $1;
        my $res = $self->check_belief(lc($channel), $target, $nick);
        return $self->tell($sender, $res);
    }
    elsif ($message =~ /^where\s+do\s+you\s+believe\s+($NICK_RX)$PUNC_RX/i) {
        my $target = $1;
        my $res = $self->believe_where(($channel), $target, $nick);
        return $self->tell($sender, $res);
    }
    # Op on Command
        elsif ($message =~ /^spread\s+ops$PUNC_RX/i) {
              $self->reset_opq(lc($channel));
              return $self->tell($sender, "Ok");
        }
    # report owner
    elsif ($message =~ /^who\s+is\s+your\s+owner$PUNC_RX/i) {
            return $self->tell($sender, "I'm owned by $$self{owner}");
        }
    # report all trusts
    elsif ($message =~ /^who\s+do\s+you\s+trust$PUNC_RX/i) {
            return $self->tell($sender, "I trust: ".CORE::join(', ', @{ $self->list_ops }));
        }
    # report nick back to sender
        elsif ($message =~/^who\s+am\s+i$PUNC_RX/i) {
            return $self->tell($sender, "You are $nick");
    }
    ##################################################################
    ## Other things.

    # Help
    elsif ($message =~ /^help/i) {
        $self->tell($sender, "I'm an opbot. I op people I trust ($self->{_BOT_}->{Nick}, trust <nick>), and voice people I believe ($self->{_BOT_}->{Nick}, believe <nick>).");
        $self->tell($sender, "You can invite me to other channels you want me to look after, and kick me out if I annoy you.");
        return 1;
    }

}

######################################################################################
## Event handlers
######################################################################################

sub irc_mode {
    my ($self, $bot, $nickstring, $channel, $mode, @ops) = @_[OBJECT, SENDER, ARG0 .. $#_];
    # Poking ops every time ops get poked would be very silly. So we only do
    # if it was us what woz opped, so we can wake up and op other people.
    if ( (grep($self->{_BOT_}->{Nick}, @ops) ) and $channel ) {
        $self->reset_opq(lc($channel))
    }
        return 0;
}

sub irc_nick {
    my ($self, $bot, $from, $to) = @_[OBJECT, SENDER, ARG0, ARG1];
    # If people change nicks, we should notice if they need opping.
    $self->reset_opq(keys %{ $self->channels });
    return 0;
}

sub irc_join {
   my ($self, $bot, $nickstring, $channel) = @_[OBJECT, SENDER, ARG0, ARG1];
   # when people join, we should check who need's opping.
   $self->reset_opq(lc($channel)) if $channel;
   return 0;
}

sub irc_353 { # Called when we get the repsonse from the NAMES event.
    my ($self, $bot, $server, $message, $kernel) = @_[OBJECT, SENDER, ARG0, ARG1, KERNEL];
    my (undef, $channel, @names) = split(/\s/, $message); # Get the names
    $names[0] =~ s/^\://; # FFS

    return 0 unless $channel && $channel ne "*";

    foreach my $raw (@names) {
        my $nick = $raw;
        $nick =~ s/^[\@\+]//;
        my $opped = ($raw =~ /^\@/) ? "opped" : "";
        my $voice = ($raw =~ /^\+/) ? "voiced" : "";

        if ($self->check_ops($nick, lc($channel))) {
            if ($opped) {
                delete $self->{lc($channel)}{to_op}{$nick};
            } else {
                $self->{$channel}{to_op}{$nick}++;
            }
        }

        if ($self->check_voice($nick)) {
            if ($voice or $opped) {
                delete $self->{lc($channel)}{to_voice}{$nick};
            } else {
                $self->{lc($channel)}{to_voice}{$nick}++;
            }
        }
    }
        return 0;
}

sub dotheopthing {
    my ($self) = $_[OBJECT];
    my $made_changes = undef;
    my @channels = keys(%{ $self->channels });
    foreach my $channel (@channels) {
        # Organize our data a bit so we can figure out what the hell we're gonna do
        my $change_mode = {};
        $change_mode->{$_} = 'o' for keys(%{$self->{$channel}{to_op}});
        $change_mode->{$_} = 'v' for keys(%{$self->{$channel}{to_voice}});
        delete $self->{lc($channel)}{to_op};
        delete $self->{lc($channel)}{to_voice};
        # Cleverness here groups people into lots of three, so we don't
        # flood the channel with op messages if we have to op lots of
        # people.
        # I've gone ahead and combined both the voice and ops
        # so it will do things like +oov baud, ubu, axdahut
        my @multi_op = (); my @modes = (); my %seen = ();
        for my $nick (keys(%$change_mode)) {
            next if $seen{$nick};
            $seen{$nick}++;
            if (scalar(@multi_op) < 3) { # Spec says 4. Clients rarely do > 3. So I use 3.
               push(@multi_op, $nick);
               push(@modes, $change_mode->{$nick});
            } else {
               my $op_string = lc($channel).' +'.CORE::join('', @modes).' '.CORE::join(" ", @multi_op);
               warn $op_string if $self->{DEBUG};
               $self->{_BOT_}->mode($op_string);
               @multi_op = ($nick);
               @modes = ($change_mode->{$nick});
            }
        }
        if ((scalar(@modes) > 0) && (scalar(@multi_op) > 0)) {
            my $op_string = lc($channel).' +'.CORE::join('', @modes).' '.CORE::join(" ", @multi_op);
            warn $op_string if $self->{DEBUG};
            $self->{_BOT_}->mode($op_string);
            @modes = (); @multi_op = ();
        }
    }
    return 1;
}

1;
__END__

=pod

=head1 LIMITATIONS

Currently requires Bot::Pluggable::Common

=head1 BUGS

The clever op thing appears to be working. The netsplit stuff seems to be patched.
Patches are welcome.

=head1 COPYRIGHT

    Copyright 2003, Chris Prather, All Rights Reserved

=head1 LICENSE

You may use this module under the terms of the BSD, Artistic, or GPL licenses,
any version.

=head1 AUTHOR

Chris Prather (chris@prather.org)

=cut