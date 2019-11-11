require_relative 'events/prepare_start_item_request'

module ReportPortal
  # @api private
  class EventBus
    attr_reader :event_types

    def initialize
      @event_types = {
        prepare_start_item_request: Events::PrepareStartItemRequest
      }
      @handlers = {}
    end

    def on(event_name, &proc)
      handlers_for(event_name) << proc
    end

    def broadcast(event_name, **attributes)
      event = event_types.fetch(event_name).new(**attributes)
      handlers_for(event_name).each { |handler| handler.call(event) }
    end

    private

    def handlers_for(event_name)
      @handlers[event_name] ||= []
    end
  end
end
