module Lita
  module Handlers
    # Event-related handlers
    class LockerEvents < Handler
      namespace 'Locker'

      include ::Locker::Label
      include ::Locker::Misc
      include ::Locker::Regex
      include ::Locker::Resource

      on :lock_attempt, :lock_attempt
      on :unlock_attempt, :unlock_attempt

      def lock_attempt(payload)
        label      = payload[:label]
        user       = Lita::User.find_by_id(payload[:user_id])
        request_id = payload[:request_id]

        return unless Label.exists?(label)
        l = Label.new(label)
        if l.lock!(user.id)
          robot.trigger(:lock_success, request_id: request_id)
        else
          robot.trigger(:lock_failure, request_id: request_id)
        end
      end

      def unlock_attempt(payload)
        label      = payload[:label]
        request_id = payload[:request_id]

        return unless Label.exists?(label)
        l = Label.new(label)
        if l.unlock!
          robot.trigger(:unlock_success, request_id: request_id)
        else
          robot.trigger(:unlock_failure, request_id: request_id)
        end
      end

      Lita.register_handler(LockerEvents)
    end
  end
end
