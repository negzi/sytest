multi_test "Typing notifications don't leak",
   requires => [qw( make_test_room do_request_json_for await_event_for local_users
                    can_create_room can_set_room_typing )],

   do => sub {
      my ( $make_test_room, $do_request_json_for, $await_event_for, $local_users ) = @_;
      my $creator = $local_users->[0];
      my $member  = $local_users->[1];
      my $nonmember = $local_users->[2];

      my $room_id;

      $make_test_room->( $creator, $member )->then( sub {
         ( $room_id ) = @_;
         pass "Created room";

         $do_request_json_for->( $creator,
            method => "PUT",
            uri    => "/rooms/$room_id/typing/:user_id",

            content => { typing => 1, timeout => 30000 }, # msec
         );
      })->then( sub {
         Future->needs_all( map {
            my $recvuser = $_;

            $await_event_for->( $recvuser, sub {
               my ( $event ) = @_;
               return unless $event->{type} eq "m.typing";
               return unless $event->{room_id} eq $room_id;

               return 1;
            })
         } $creator, $member );
      })->then( sub {
         pass "Members received notification";

         Future->wait_any(
            delay( 2 ),

            $await_event_for->( $nonmember, sub {
               my ( $event ) = @_;
               return unless $event->{type} eq "m.typing";
               return unless $event->{room_id} eq $room_id;

               return 1;
            })->then_fail( "Received unexpected typing notification" ),
         );
      })->then( sub {
         pass "Non-member did not receive it up to timeout";

         Future->done(1);
      });
   };