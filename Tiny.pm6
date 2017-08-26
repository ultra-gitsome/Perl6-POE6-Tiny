# POE6/Tiny

####
# This module is a 'Tiny' Perl6 fork of POE using Ingo's POE-0.0.1 module
# Author credits: (Perl6) POE-0.0.1, Ingo Blechschmidt C<< <iblech@web.de> >>
#                 (Perl5) POE-0.0.1, Ingo Blechschmidt C<< <iblech@web.de> >>
# 
# The intent is to satisfy simple POE needs in Perl6, not to re-write POE
# Therefore this module does not have all of the bookkeeping embedded within POE,
# and surely makes the POE code more stable.
# Note. The 1st iteration of this code is nearly an identical fork of POE-0.0.1
#
####
#module POE6::Tiny-0.0.1;

my $p6_version = '0.0.1';
my $poe6_debug = 1;

class POE6::Kernel {
  # FIFO containing the events to call.
  has Code @!events;
  has Code @!async_events;

  submethod BUILD() {
    die "There can only be one instance of POE::Kernel."
      if defined $POE::Kernel;

    $POE::Kernel = self;
  }

  # Private method which pushes a given $callback to @:events.
  method !enqueue(&callback) {
    push @!events, &callback;
  }
  
  # Private method which pushes a given $callback to @:async_events.
  method !async-queue(&callback) {
    push @!async_events, &callback;
  }

  # Perform one step -- i.e. get an event from @:events and call it.
  method !step() {
    if @!async_events {
		await Supply.from-list(@!async_events).throttle: 1, {
			start {
				if $poe6_debug {
					say "Next async event [$_]";
				}
				my &callback = $_;
				&callback();
			}
		}
	}
    return unless @!events;
    my &callback = shift @!events;
    return &callback();
  }

  method run() {
    while @!events {
      self!step;
    }
  }

  # Post $event to $session and return the result.
  # The session's event handler won't be executed until @!events[0] =:= the
  # callback we enqueue().
  method post($session, Str $event, *@args) {
    # Push our callback on @!events.
	# POE::Session check - type checking may be enabled in the future
	if $poe6_debug {
		say "session class name: " ~ $session.^name;
	}
    self!enqueue({
      my $result = $session.dispatch($event, [,] @args);
      $result;
    });

    # And enter the runloop again.
    self!step(); 
  }

  # Delay an $event to $session and return nothing - yet.
  method delay($session, Str $event, *@args) {
    die 'Please add delay method into POE6::Kernel.';

    # And enter the runloop again.
    self!step(); 
  }

  # Yield an $event to $session and return nothing - yet.
  method yield($session, Str $event, *@args) {
    # Push our async callback on @!async_events.
	if $poe6_debug {
		say "session class name: " ~ $session.WHO;
	}
    self!async-queue({
      my $result = $session.dispatch($event, [,] @args);
      $result;
    });

    # And enter the runloop again.
    self!step(); 
  }

}

class POE6::Session {
  method dispatch(Str $event, *@args) {
    die 'Please override &dispatch in your subclass of POE6::Session.';
  }
}


#
#Note. The global variable $POE::Kernal should be created outside of the class package
#  to ensure the namespace is populated. Otherwise a 'Cannot find symbol' error may occur.
  
##--Notepad++
