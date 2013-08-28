# Copyright 2013 anthony cantor
# This file is part of sliceman.
#
# sliceman is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# sliceman is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with sliceman.  If not, see <http://www.gnu.org/licenses/>.

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

	SNDFILE_OPTS = {
		:mode => :WRITE,
		:format => :WAV,
		:encoding => :PCM_16,
	}

	def self.path_format(infile, n, dest_prefix)
		zeros = 1
		x = n
		while (x = x/10) > 0
			zeros += 1
		end
	
		return "#{dest_prefix}%0#{zeros}d.wav"
	end

	def self.file_output_bloc(infile, outpath, &bloc)
		return Proc.new do |data, idx|
			opts = SNDFILE_OPTS.merge({
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

	def self.slice_every_n(infile, n, dest_prefix, &bloc)
		outpath = path_format(infile, (infile.info.frames/n)+1, dest_prefix)

		return each_n_frames(
			infile, n,
			&file_output_bloc(infile, outpath, &bloc)
		)
	end

	def self.subdivision_size_for_n(infile, n)
		if n > infile.info.frames 
			raise ArgumentError.new, "#{n} = n > infile.info.frames = #{infile.info.frames}"
		end

		amt = infile.info.frames/n
		remain = infile.info.frames % n

		return amt, remain
	end

	def self.concat_snd_matrices(a, b)
		m = a.rows + b.rows
		n = a.columns 

		if n != b.columns
			raise "expected matrices to have the same number of columns"
		end

		return GSLng::Matrix::new(m, n) do |i,j|
			if i < a.rows
				a[i,j]
			else
				b[i-a.rows,j]
			end
		end
	end

	def self.subdivide_frames_by_n(infile, n, &bloc)
		amt, r = subdivision_size_for_n(infile, n)

		slices = []
		remain = Proc.new do |rmn| 
			slices[-1] = concat_snd_matrices(slices.last, rmn)
		end

		each_n_frames(infile, amt, remain) do |data|
			slices << data
		end

		slices.each_with_index do |data, idx|
			bloc.call(data, idx)
		end

		return amt, r
	end

	def self.subdivide_by_n(infile, n, dest_prefix, &bloc)
		outpath = path_format(infile, n, dest_prefix)

		return self.subdivide_frames_by_n(
			infile, n,
			&file_output_bloc(infile, outpath, &bloc)
		)
	end
end
