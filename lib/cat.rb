#!/usr/bin/env ruby

require 'timeout'
require 'thread'
require "serialport"
require "logger"

class CAT
	class Message
		def self.parse(message)
			raise NotImplementedError
		end
	end

	def self.instance(opts)
		file = "#{File.dirname(__FILE__)}/cat/model/#{opts[:model].to_s.downcase}.rb"
		require file
		klass = self.const_get(opts[:model]) or raise "Classs #{opts[:model]} is not defined in #{file}"
		klass.new(opts)
	end

	attr_reader :status

	def initialize(opts)
		@status = {}
		@port = SerialPort.new(
			opts[:port],
			opts[:baudrate],
			opts[:databit] || 8,
			opts[:stopbit] || 1,
			opts[:paritycheck] || SerialPort::NONE
		)
		@port.set_encoding(Encoding::BINARY)

		@logger = Logger.new(opts[:log] || $stdout)
		@logger.level = opts[:debug] ? Logger::DEBUG : Logger::WARN

		@ai_queue = Queue.new
		@read_queue  = Queue.new
		@read_thread = Thread.start do
			Thread.abort_on_exception = true
			while message = @port.gets(";")
				@logger.debug "<< #{message}"
				begin
					msg = message_class.parse(message)
					@read_queue.push(msg)
					@ai_queue.push(msg) if @ai_queue
				rescue => e
					@logger.warn e.inspect
					@logger.warn message
				end
			end
		end

		@write_queue = Queue.new
		@write_thread = Thread.start do
			Thread.abort_on_exception = true
			while m = @write_queue.pop
				@logger.info ">> #{m}"
				@port.write(m)
			end
		end
	end

	# define public methods
	def frequency=(freq, try=5)
		raise NotImplementedError
	end

	def mode=(mode, try=5)
		raise NotImplementedError
	end

	def power=(power, try=5)
		raise NotImplementedError
	end

	def width=(width, try=5)
		raise NotImplementedError
	end

	def noise_reduction=(level, try=5)
		raise NotImplementedError
	end

	def command(cmd, params="", n=5)
		raise NotImplementedError
	end


	private

	def message_class
		Message
	end

	def write(cmd, param="")
		@write_queue << "#{cmd}#{param};"
	end

	def read(cmd, param="")
		write(cmd, param)
		timeout(1) do
			while m = @read_queue.pop
				if m.cmd == cmd
					return m
				end
			end
		end
	end
end
