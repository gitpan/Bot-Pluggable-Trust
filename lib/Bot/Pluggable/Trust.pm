package Bot::Pluggable::Trust;
$VERSION = 0.05;
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

Much of this code was 'Borrowed' from the Slavorg2 PoCo::Object bot 
found at L<http://jerakeen.org/cms/slavorg2> and converted over to  
Bot::Pluggable despite the issues brought up on 
L<http://www.jerakeen.org/cms/irc/bots>

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
    for my $event qw(irc_353 dotheopthing re_join) {
        $self->{_BOT_}->add_event($event);
    }  
    $self->load(); 
}

sub quit {
    my ($self) = @_;
    $self->save();
    $self->{_BOT_}->shutdown;
    exit;
}

sub load {
    my ($self) = @_;
    $self->load_channels();
    for my $channel (keys %{ $self->Channels }) {
        print STDERR"Loading Ops\n" if $self->{DEBUG};
        $self->load_ops($channel);
        print STDERR "Loading Voice\n" if $self->{DEBUG};
        $self->load_voice($channel);
    }
}

sub save {
    my $self = shift;
    print STDERR "save\n" if $self->{DEBUG};
    $self->save_channels;
    for my $channel (keys %{ $self->Channels }) {
        print STDERR "Saving Ops\n" if $self->{DEBUG};
        $self->save_ops($channel);
        print STDERR "Saving Voice\n" if $self->{DEBUG};
        $self->save_voice($channel);
    }
}
sub load_channels {
    my ($self) = @_;
    my $channels = {};
    my $file = $self->{_BOT_}->{Nick}.'_channels';
    if (open(READ, "$file")) {
        while (<READ>) {
            chomp;
            $channels->{$_} = {};
        }
        close(READ);
    } else {
        print STDERR "Can't open channels file ($file): $!\n";
    }
    $self->Channels($channels);
}

sub load_ops {
    my ($self, $channel) = @_;
    my $channels = $self->Channels;
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
    $self->Channels($channels);
}

sub load_voice {
    my ($self, $channel) = @_;
    my $channels = $self->Channels;
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
    $self->Channels($channels);
}

sub save_channels {
    my ($self) = @_;
    my $channels = $self->Channels;
    my $file = $self->{_BOT_}->{Nick}.'_channels';
    if (open(READ, ">$file")) {
        print READ "$_\n" for keys(%{$self->Channels});
        close READ;
    } else {
        print STDERR "Can't save channels file ($file): $!\n";
    }
    $self->Channels($channels);
}

sub save_ops {
    my ($self, $channel) = @_;
    my $channels = $self->Channels;
    my $file = "$self->{_BOT_}->{Nick}_ops";
    if (open(READ, ">$file")) {
        print READ "$_\n" for keys(%{$channels->{$channel}{ops}});
        close READ;
    } else {
        print STDERR "Can't save ops file ($file): $!\n";
    }
    $self->Channels($channels);
}

sub save_voice {
    my ($self, $channel) = @_;
    my $channels = $self->Channels;
    my $file = "$self->{_BOT_}->{Nick}_voice";
    if (open(READ, ">")) {
        print READ "$_\n" for keys(%{$channels->{$channel}{voice}});
        close READ;
    } else {
        print STDERR "Can't save voice file ($file): $!\n";
    }
    $self->Channels($channels);
}



sub add_op {
    my ($self, $target, $channel) = @_;
    print STDERR "add_op $target $channel\n" if $self->{DEBUG};
    my $channels = $self->Channels;
    $channels->{$channel}{ops}{$target}++;
    delete $channels->{$channel}{voice}{$target} if $channels->{$channel}{voice}{$target};
    $self->Channels($channels);
    $self->save();
}

sub remove_op {
    my ($self, $target, $channel) = @_;
    print STDERR "remove_op $target $channel\n" if $self->{DEBUG};
    my $channels = $self->Channels;
    delete $channels->{$channel}{ops}{$target};
    delete $channels->{$channel}{voice}{$target} if $channels->{$channel}{voice}{$target};
    $self->Channels($channels);
    $self->save();
}

sub add_voice {
    my ($self, $target, $channel) = @_;
    print STDERR "add_voice $target $channel\n" if $self->{DEBUG};
    my $channels = $self->Channels;
    $channels->{$channel}{voice}{$target}++;
    $self->Channels($channels);
    $self->save();
}

sub remove_voice {
    my ($self, $target, $channel) = @_;
    print STDERR "remove_voice $target $channel\n" if $self->{DEBUG};
    my $channels = $self->Channels;
    delete $channels->{$channel}{voice}{$target};
    $self->Channels($channels);
    $self->save();
}

sub join_channel {
    my ($self, $target) = @_;   
    print STDERR "join_channel $target\n" if $self->{DEBUG};
    $self->{_BOT_}->join($target);
    my $channels = $self->Channels();
    $channels->{$target} = {};
    $self->Channels($channels);
    $self->save();
}

sub leave_channel {
    my ($self, $target) = @_;
    print STDERR "leave_channel $target\n" if $self->{DEBUG};
    $self->{_BOT_}->part($target);
    my $channels = $self->Channels;
    delete $channels->{$target};
    $self->Channels($channels);
    $self->save();
}

sub check_ops {
		my ($self, $nick, $channel) = @_;
		if ($nick eq $self->{owner}) {
			 return 1; #Bawhahaha!
		}
		elsif ($channel) {
			 return $self->Channels->{$channel}{ops}{$nick};
		} 
		else {
			 for $channel (keys %{ $self->Channels }) {
			 		 return 1 if $self->Channels->{$channel}{ops}{$nick};
			 }
		}		
}

sub check_voice {
		my ($self, $nick, $channel) = @_;
		if ($channel) {
			 return $self->Channels->{$channel}{voice}{$nick};
		} else {
			 for $channel (keys %{ $self->Channels }) {
			 		 return 1 if $self->Channels->{$channel}{voice}{$nick};
			 }
		}		
}

sub list_ops {
		my $self = shift;
		my %ops = ();
 	  for my $channel (keys %{ $self->Channels }) {
			   for my $user (keys %{ $self->Channels->{$channel}{ops} }) {
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
        $self->{_BOT_}{recent_names} = time && $self->{_BOT_}->names($channel) # reset the names list  
              unless (time - ( $self->{_BOT_}{recent_names} || 0 ) < 10);  # Unless we've asked for names recently....
    }    
}

sub trust {
    my ($self, $channel, $target, $nick) = @_;
    if ($self->check_ops($target, $channel)) {
        return "But I already trust $target";
    } elsif (!($self->check_ops($nick, $channel))) {
        return "But I don't trust >you<, $nick";
    } elsif (!$channel) {
        return "Uh, you need to tell me that again in a channel.";
    } else {
        eval {
            print STDERR "Trusting '$target' due to '$nick'\n";
            $self->add_op($target, $channel);
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
        return "But I already >trust< $target";
    } elsif (!($self->check_ops($nick, $channel))) {
        return "But I don't trust >you<, $nick";
    } elsif (!$channel) {
        return "Uh, you need to tell me that again in a channel.";
    } else {
        eval {
            print STDERR "Voicing '$target' due to '$nick'\n";
            $self->add_voice($target, $channel);
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
        print STDERR "$nick tried to distrust $$self{owner}. Telling him to fuck right off.\n";
        return "Yeah, right. As if.";
    } elsif (!$channel) {
        return "Uh, you need to tell me that again in a channel.";				 
    } else {
        eval {
            print STDERR "Distrusting '$target' due to '$nick'\n";        
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
        return "But I don't believe $target";
    } elsif ($self->check_ops($target, $channel)) {
        return "But I >trust< $target";
    } elsif (!($self->check_ops($nick))) {
        return "But I don't trust >you<, $nick";
    } elsif (!$channel) {
        return "Uh, you need to tell me that again in a channel.";
    } else {
        eval {
            print STDERR "De-voicing '$target' due to '$nick'\n";
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
        @rooms = keys %{ $self->Channels };
   }
   else {
        my $channels = $self->Channels();
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
        for (keys %{ $self->Channels() }) {
            $rooms{$_}++;
        }
    }
    else {
        my $channels = $self->Channels();
        for my $channel (keys %$channels) {
            $rooms{$channel}++ if $channels->{$channel}{ops}{$target};
            $rooms{$channel}++ if $channels->{$channel}{voice}{$target};
        }
    }
  	return "I believe $target in ". CORE::join(', ', keys %rooms) if (keys %rooms); 
		return "I don't trust $target anywhere";
}

sub told_join {
	my ($self, $channel, $nick) = @_;
  unless ($self->check_ops($nick)) {
		  return "Sorry, $nick, I don't trust you.";
  }
  else { # TODO this is bad, we should make sure we sucessfully join the channel, really.
    eval {
        print STDERR "Told to join $channel by '$nick'\n";
        $self->join_channel($channel);
    };
    if ($@) { 
        warn "there was a problem: $@";
        return "I seem to be having trouble doing that";
    }
    return "Joining $channel. I'll remember this.";
  } 		
}

sub told_part {
  my ($self, $channel, $target, $nick) = @_;
  unless ($self->check_ops($nick)) {
    return "Sorry, $nick, I don't trust you.";
  }
  else {
    eval {
        print STDERR "Told to leave $channel by $nick\n";
        $self->leave_channel($channel);
    };
    if ($@) { 
        warn "there was a problem: $@";
        return "I seem to be having trouble doing that";
    }
			return "Ok, $nick, bye. I'll remember this.";
  } 
}

sub told {
    my ($self, $nick, $channel, $message) = @_;
    my $sender = $channel || $nick;
    
    my $PUNC_RX = qr([?.!]?);
    my $NICK_RX = qr([][a-z0-9^`{}_|\][a-z0-9^`{}_|\-]*)i;

    # Trust 
    if ($message =~ /^trust\s+($NICK_RX)$PUNC_RX/i) {
        my $target = $1;
        my $res = $self->trust($channel, $target, $nick);
        $self->tell($sender, $res);
    }
    # Believe 
    elsif ($message =~ /^believe\s+($NICK_RX)$PUNC_RX/i) {
        my $target = $1;
        my $res = $self->believe($channel, $target, $nick);
        $self->tell($sender, $res);
    }
    # Distrust 
    elsif ($message =~ /^distrust\s+($NICK_RX)$PUNC_RX/i) {
        my $target = $1;
        my $res = $self->distrust($channel, $target, $nick);
        $self->tell($sender, $res);
    }
    # Disbelief
    elsif ($message =~ /^disbelieve\s+($NICK_RX)$PUNC_RX/i) {
        my $target = $1;
        my $res = $self->disbelieve($channel, $target, $nick);
        $self->tell($sender, $res);
    }
    # Check Trust
    elsif ($message =~ /^do\s+you\s+trust\s+($NICK_RX)$PUNC_RX/i) {
        my $target = $1;
        my $res = $self->check_trust($channel, $target, $nick);
        $self->tell($sender, $res);
    }
		elsif ($message =~ /^where\s+do\s+you\s+trust\s+($NICK_RX)$PUNC_RX/i) {
       my $target = $1;
        my $res = $self->trust_where($channel, $target, $nick);
        $self->tell($sender, $res);
    }
    # Check Belief
    elsif ($message =~ /^do\s+you\s+believe\s+($NICK_RX)$PUNC_RX/i) {
        my $target = $1;
        my $res = $self->check_belief($channel, $target, $nick);
        $self->tell($sender, $res);
		}
		elsif ($message =~ /^where\s+do\s+you\s+believe\s+($NICK_RX)$PUNC_RX/i) {
        my $target = $1;
        my $res = $self->believe_where($channel, $target, $nick);
        $self->tell($sender, $res);
    }
    # Op on Command
		elsif ($message =~ /^do\s+the\s+op\s+thing$PUNC_RX/i) {
			  $self->dotheopthing();
		}
    # report owner
    elsif ($message =~ /^who\s+is\s+your\s+owner$PUNC_RX/i) {
	  		$self->tell($sender, "I'm owned by $$self{owner}");
		}
    # report all trusts
    elsif ($message =~ /^who\s+do\s+you\s+trust$PUNC_RX/i) {
				$self->tell($sender, "I trust: ".CORE::join(', ', @{ $self->list_ops }));
		}
    # report nick back to sender
		elsif ($message =~/^who\s+am\s+i$PUNC_RX/i) { 
			  $self->tell($sender, "You are $nick");
    }      
    ##################################################################
    ## Other things.

    # Help
    elsif ($message =~ /^help/i) {
        $self->tell($sender, "I'm an opbot. I op people I trust ($self->{_BOT_}->{Nick}, trust <nick>), and voice people I believe ($self->{_BOT_}->{Nick}, believe <nick>).");
        $self->tell($sender, "You can invite me to other channels you want me to look after, and kick me out if I annoy you.");
    }
    # Join
    elsif ($message =~ /^join\s+(.*)$/i) {
         my $target = $1;
         my $res = $self->told_join($target, $nick);
				 $self->tell($sender, $res);
    }
    # Leave
    elsif ($message =~ /^(?:leave|part)\s+(.*)$/i) {
         my $target = $1;
         my $res = $self->part($channel, $target, $nick);
				 $self->tell($sender, $res);
    }
		# Quit
    elsif ($message =~ /^(?:quit)$/i) {
         my $res = $self->quit($nick);
				 $self->tell($sender, $res);
    }	 
}
    
######################################################################################
## Event handlers
######################################################################################

sub re_join {
    my ($self, $bot, $channel) = @_[SENDER, OBJECT, ARG0];
    print STDERR "Attempting to rejoin $channel\n" if $self->{DEBUG};
    $self->join_channel($channel);
}

sub irc_001 {
    my ($self, $bot, $kernel) = @_[OBJECT, SENDER, KERNEL];
    $self->init($bot);
		 $bot->join($_) for keys %{ $self->Channels };
    $kernel->delay_set("dotheopthing", $$self{delay} || 10, $bot);
		 return 0;
}

sub irc_public {
    my ($self, $bot, $nickstring, $channels, $message) = @_[OBJECT, SENDER, ARG0, ARG1, ARG2];  
    my $nick = $self->nick($nickstring);
    my $me = $bot->{Nick};
    $self->told($nick, $channels->[0], $1) if ($message =~ m/^\s*$me[\:\,\;\.]?\s*(.*)$/i);
    unless (time - ( $self->{recent_names} || 0 ) < 10) { # Unless we've asked for names recently....
        $self->{recent_names} = time;
        $bot->names($channels->[0]);
    }
		return 0;
}    

sub irc_invite {
    my ($self, $bot, $nickstring, $channel) = @_[OBJECT, SENDER, ARG0, ARG1];
    my $nick = $self->nick($nickstring);
    if ($self->check_ops($nick)) {
        print STDERR "Invited to $channel by $nick\n";
        $self->join_channel($channel);
        # TODO this is bad, we should make sure we sucessfully join the channel, really.
        return 1;
    } else {
        $self->tell($bot, $nick, "Sorry, I don't trust you enough");
        return 0;
    }
}

sub irc_kick {
    my ($self, $kernel, $nickstring, $channel, $kicked, $reason) = @_[OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3];
    if ($kicked eq $self->{_BOT_}{Nick}) {
        print STDERR "Kicked from $channel by $nickstring ($reason)\n";
        $kernel->delay_set("re_join", $$self{delay} || 10, $channel);
    }
		 return 0;
}

sub irc_mode {
    my ($self, $bot, $nickstring, $channel, $mode, @ops) = @_[OBJECT, SENDER, ARG0 .. $#_];
    # Poking ops every time ops get poked would be very silly. So we only do
    # if it was us what woz opped, so we can wake up and op other people.
    if ( (grep($self->{_BOT_}{Nick}, @ops) ) and $channel ) {
        $self->reset_opq($channel)
    } 
		return 0;
}

sub irc_msg {
    my ($self, $bot, $nickstring, $recipients, $message) = @_[OBJECT, SENDER, ARG0, ARG1, ARG2];
    my $nick = $self->nick($nickstring);
    $self->told($nick, undef, $message);
		return 0;
}

sub irc_nick {
    my ($self, $bot, $from, $to) = @_[OBJECT, SENDER, ARG0, ARG1];
    # If people change nicks, we should notice if they need opping.
    $self->reset_opq(keys %{$self->Channels});
 		return 0;
}

sub irc_join {
   my ($self, $bot, $nickstring, $channel) = @_[OBJECT, SENDER, ARG0, ARG1];
		$self->reset_opq($channel) if $channel;
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
        
        if ($self->check_ops($nick, $channel)) {
            if ($opped) {
                delete $self->{$channel}{to_op}{$nick};
            } else {
                $self->{$channel}{to_op}{$nick}++;
            }
        }
        
        if ($self->check_voice($nick)) {
            if ($voice or $opped) {
                delete $self->{$channel}{to_voice}{$nick};
            } else {
                $self->{$channel}{to_voice}{$nick}++;
            }
        }
    }
		return 0;
}

sub dotheopthing {
    my ($self, $bot) = @_[OBJECT, ARG0];
    my $made_changes = undef;
    foreach my $channel (keys(%{ $self->Channels })) {
        # Organize our data a bit so we can figure out what the hell we're gonna do
        my $change_mode = {};
        $$change_mode{$_} = 'o' for keys(%{$self->{$channel}{to_op}});
        $$change_mode{$_} = 'v' for keys(%{$self->{$channel}{to_voice}});
        
        # Cleverness here groups people into lots of three, so we don't
        # flood the channel with op messages if we have to op lots of
        # people.
        #
        # I've gone ahead and combined both the voice and ops 
        # so it will do things like +oov baud, ubu, axdahut
        my $multi_op = []; my $modes = [];
        for my $nick (keys(%$change_mode)) {
        
            next if (time() - ( $self->{$channel}{recent_ops}{$nick} || 0) < $$self{lag});
            $self->{$channel}{recent_ops}{$nick} = time;
            
            if (scalar(@$multi_op) < 3) { # Spec says 4. Clients rarely do > 3. So I use 3.
               push(@$multi_op, $nick);
               push(@$modes, $$change_mode{$nick});
            } else {
               $bot->mode("$channel +".CORE::join('', @$modes).' '.CORE::join(" ", @$multi_op)); 
               $multi_op = [$nick];
               $modes = [$$change_mode{$nick}]
            }
            $bot->mode("$channel +".CORE::join('', @$modes).' '.CORE::join(" ", @$multi_op)) if $modes && $multi_op;   
        }
        delete $self->{$channel}{to_op};
        delete $self->{$channel}{to_voice};
    }
    $poe_kernel->delay_set("dotheopthing", $$self{delay} || 10, $bot);
    return 1;
}

1;
__END__

=pod

=head1 LIMITATIONS

Currently requires Bot::Pluggable::Common

=head1 BUGS

Currently it isn't doing the clever multi-op thing and there was one incident 
of a infinite loop of opping just after a netsplit, when adding new trusted 
users obviously Patches are welcome.

=head1 COPYRIGHT

    Copyright 2003, Chris Prather, All Rights Reserved

=head1 LICENSE

You may use this module under the terms of the BSD, Artistic, or GPL licenses,
any version.

=head1 AUTHOR

Chris Prather (chris@prather.org)

=cut