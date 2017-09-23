# POE6/MySession

####
# This is a sample session class for the 'Tiny' Perl6 fork of POE.
#
# Disclaimer:
#   This code is a simple starting point and not intended to show
#   a complete and functional app.
####

my $p6_version = '0.0.1';

use POE6::Roles;

class MySession does POE6::Session {
	method dispatch(Str $event, *@args) {
		say "check for say hello [$event] size["~@args.elems~"]";
		given $event {
			when "say_hello" {
				say "Saying Hello, @args[0]!";
				return "Hello, @args[0]!";
			}

		}
	}

	method dispatch_any(Str $event, *@args) {
		#say "[DIS-ANY] check for say hello [$event] size["~@args.elems~"]";
		given $event {
			when "say_hello" {
				return "Hello, @args[0]!";
			}

		}
	}

	method dispatch_sig(Str $event, *@args) {
		#say "[d_evt] check for say hello [$event] size["~@args.elems~"]";
		given $event {
			when "say_hello" {
				say "Hello, @args[0]!";
				return;
			}
		}
	}
	
}
