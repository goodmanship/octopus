# Implementation courtesy of db-charmer.
module Octopus
  module AbstractAdapter
    module OctopusShard

      class InstrumenterDecorator < ActiveSupport::BasicObject
        def initialize(adapter, instrumenter)
          @adapter = adapter
          @instrumenter = instrumenter
        end

        def instrument(name, payload = {}, &block)
          payload[:octopus_shard] ||= @adapter.octopus_shard
          @instrumenter.instrument(name, payload, &block)
        end

        def method_missing(meth, *args, &block)
          @instrumenter.send(meth, *args, &block)
        end
      end

      def self.included(base)
        base.alias_method_chain :initialize, :octopus_shard
      end

      def octopus_shard
  			# @config is not present if this method is called on an ActiveRecord:ConnectionAdapters::SQLServerAdapter object
				# so rebuild it here as a local variable "config," as a workaround -Rio
				config = begin
					file_name = Octopus.directory() + "/config/shards.yml"
					if File.exists? file_name
						config ||= HashWithIndifferentAccess.new(YAML.load(ERB.new(File.open(file_name).read()).result))[Octopus.env()]
					else
						config ||= HashWithIndifferentAccess.new
					end
				end
				config[:octopus_shard]
      end

      def initialize_with_octopus_shard(*args)
        initialize_without_octopus_shard(*args)
        @instrumenter = InstrumenterDecorator.new(self, @instrumenter)
      end

    end
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, Octopus::AbstractAdapter::OctopusShard)
