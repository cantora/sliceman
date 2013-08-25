require 'sndfile'

module Sliceman

	def self.each_n_frames(infile, n, remainder=nil, &bloc)
		raise ArgumentError.new, "invalid n: #{n.inspect}" if n < 1

		idx = 0
		remain = nil
		loop do 
			data = infile.read(n)

			if !remain.nil? && (!data.nil? && data.frames > 0)
				raise "got more data after remainder"
			end

			if data.nil? || data.frames == 0
				if !remain.nil? && remain.frames > 0
					if remainder.nil?
						bloc.call(remain, idx)
					else
						remainder.call(remain, idx)
					end
				end
				break

			elsif data.frames > n
				raise "didnt expect more frames than #{n}"
			elsif data.frames == n
				bloc.call(data, idx)
			elsif data.frames < n && data.frames > 0
				remain = data

			else
				raise "didnt expect negative frames!"
			end
			
			idx += 1
		end
	end

	def self.slice_every_n(infile, n, dest_prefix, &bloc)
		sndfile_opts = {
			:mode => :WRITE,
			:format => :WAV,
			:encoding => :PCM_16,
		}

		amt = (infile.info.frames/n)+1;
		zeros = 1
		x = amt
		while (x = x/10) > 0
			zeros += 1
		end
		outpath = "#{dest_prefix}%0#{zeros}d.wav"

		each_n_frames(infile, n) do |data, idx|
			opts = sndfile_opts.merge({
				:channels => infile.info.channels, 
				:samplerate => infile.info.samplerate
			})

			fname = sprintf(outpath, idx)
			Sndfile::File.open(fname, opts) do |fout|
			    fout.write(data)
			end

			bloc.call(fname, idx) if !bloc.nil?
		end
	end
end
