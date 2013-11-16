#!/usr/bin/env ruby

#if defined? Bundler ## Act as Gemfile for `bundle install --gemfile $0`
#	source "https://rubygems.org"
#	gem "serialport"
#end

require 'rubygems'
require 'bundler'
require 'timeout'

Bundler.require

require 'thread'

class CAT
	class FT450D < CAT
		BAUDRATE    = 4800
		DATABIT     = 8
		STOPBIT     = 2
		PATITYCHECK = SerialPort::NONE

		class Message
			MODE_MAP = {
				"1" => :LSB,
				"2" => :USB,
				"3" => :CW,
				"4" => :FM,
				"5" => :AM,
				"6" => :DATA_RTTY_LSB,
				"7" => :CW_R,
				"8" => :USER_L,
				"9" => :DATA_RTTY_USB,
				"B" => :FM_N,
				"C" => :USER_U,
			}

			attr_reader :cmd, :params

			def self.parse(message)
				_, cmd, params = *message.match(/^(..)(.+);/)
				klass = Message.const_get(cmd.to_sym) rescue nil
				msg = (klass || Message).new(cmd, params)
				msg.parse_params
				msg
			end

			def initialize(cmd, params)
				@cmd = cmd
				@params = params
			end

			def parse_params
			end

			class IF < Message
				attr_reader :memory_channel
				attr_reader :frequency
				attr_reader :clarifier
				attr_reader :rx_clar
				attr_reader :tx_clar
				attr_reader :mode
				attr_reader :type
				attr_reader :ctcss
				attr_reader :tone_number
				attr_reader :shift

				def parse_params
					matched = self.params.match(%r{
						(?<memory_channel>...)
						(?<frequency>........)
						(?<clarifier>.....)
						(?<rx_clar>.)
						(?<tx_clar>.)
						(?<mode>.)
						(?<type>.)
						(?<ctcss>.)
						(?<tone_number>..)
						(?<shift>.)
					}x)

					@memory_channel = matched[:memory_channel].to_i
					@frequency = matched[:frequency].to_i
					@clarifier = matched[:clarifier].to_i
					@rx_clar = matched[:rx_clar] == '1'
					@tx_clar = matched[:tx_clar] == '1'
					@mode = MODE_MAP[matched[:mode]]
					@type = {
						"0" => :VFO,
						"1" => :Memory,
						"2" => :Memory_Tune,
						"3" => :QMB,
					}[matched[:type]]
					@ctcss = {
						"0" => :CTCSS_OFF,
						"1" => :CTCSS_ENC_DEC,
						"2" => :CTCSS_ENC,
					}[matched[:ctcss]]
					@tone_number = matched[:tone_number]
					@shift = {
						"0" => :simplex,
						"1" => :plus_shift,
						"2" => :minus_shift,
					}[matched[:shift]]
				end
			end

			class FA < Message
				attr_reader :frequency
				def parse_params
					@frequency = self.params.to_i
				end
			end

			class FB < FA
			end

			class PC < Message
				attr_reader :power
				def parse_params
					@power = self.params.to_i
				end
			end

			class MD < Message
				attr_reader :mode
				def parse_params
					@mode = MODE_MAP[self.params[1]]
				end
			end
		end


		def initialize(args)
			@port = SerialPort.new(
				args[:port],
				BAUDRATE,
				DATABIT,
				STOPBIT,
				PATITYCHECK
			)

			@read_queue  = Queue.new
			@read_thread = Thread.start do
				Thread.abort_on_exception = true
				while message = @port.gets(";")
					msg = Message.parse(message)
					@read_queue.push(msg)
				end
			end
		end

		def status(&block)
			command "AI", "0"
			@read_queue.pop until @read_queue.empty?

			m = read "IF"
			status = {
				:frequency => m.frequency,
				:mode      => m.mode,
				:power     => nil,
			}

			m = read "PC"
			status[:power] = m.power

			if block
				block.call(status)
				command "AI", "1"
				while m = @read_queue.pop
					case m
					when Message::IF
						status[:frequency] = m.frequency
						status[:mode] = m.mode
						block.call(status)
					when Message::FA
						status[:frequency] = m.frequency
						block.call(status)
					when Message::PC
						status[:power] = m.power
						block.call(status)
					when Message::MD
						status[:mode] = m.mode
						block.call(status)
					end
				end
			else
				status
			end
		end

		def frequency=(freq)
			if read("VS").params == "0"
				command "FA", "%08d" % freq
			else
				command "FB", "%08d" % freq
			end
		end

		def mode=(mode)
			command "MD", "0" + MODE_MAP.key(mode)
		end

		def power=(power)
			command "PC", "%03d" % power
		end

		private

		def command(cmd, param="")
			@port.write "#{cmd}#{param};"
			sleep 0.1
		end

		def read(cmd, param="")
			@port.write "#{cmd}#{param};"
			timeout(1) do
				while m = @read_queue.pop
					if m.cmd == cmd
						return m
					end
				end
			end
		end
	end
end
