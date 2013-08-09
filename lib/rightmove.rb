require 'zip/zipfilesystem'
require 'blm'

module Rightmove
	class Archive		
		attr_accessor :document, :zip_file, :branch_id, :timestamp, :blm
		
		def initialize(file = nil)
			open(file) unless file.nil?
		end
	
		def open(file)
			self.zip_file = file
			read
		end
		
		def zip_file=(file)
			if file.instance_of?(Zip::ZipFile)
				@zip_file = file
			else
				return false unless File.exists?(file)
				@zip_file = Zip::ZipFile.open(file)
			end
			parse_file_name
		end
	
		private
		def read
			blm = self.zip_file.entries.select {|v| v.to_s =~ /\.blm/i }.first
			@document = BLM::Document.new( self.zip_file.read(blm) )
		end
		
		def parse_file_name
      blm = self.zip_file.entries.select {|v| v.to_s =~ /\.blm/i }.first
			branch_id, timestamp = blm.to_s.split("_").pop(2)
			@branch_id = branch_id.to_i
			@timestamp = time_from_string(timestamp[0..7])
		end

    def time_from_string(string)
      nums = string.split("").map(&:to_i)
      take = lambda { |nums, i| nums.shift(i).join.to_i }
      Time.new(take.call(nums, 4), take.call(nums, 2), take.call(nums, 2),  take.call(nums, 2), take.call(nums, 2), take.call(nums, 2))
    end

	end
end

module BLM	
	class Row
		def method_missing(method, arguments = {}, &block)
			unless @attributes[method].nil?
				value = @attributes[method] 
				if arguments[:instantiate_with]
					return value unless value =~ /\.jpg|\.pdf/i
					if arguments[:instantiate_with].instance_of?(Zip::ZipFile)
						zip = arguments[:instantiate_with]
					else
						zip = Zip::ZipFile.open(arguments[:instantiate_with])
					end
					matching_files = zip.entries.select {|v| v.to_s =~ /#{value}/ }
					unless matching_files.empty?
						file = StringIO.new( zip.read(matching_files.first) )
						file.class.class_eval { attr_accessor :original_filename, :content_type }
						file.original_filename = matching_files.first.to_s
						file.content_type = (value =~ /\.jpg/i ? "image/jpg" : (value =~ /\.pdf/ ? "application/pdf" : "application/octet-stream" ))
						return file
					end
				else
					value
				end
			end
		end
		
		def media_fields
			self.attributes.select {|k,v| k.to_s =~ /media_(image|floor_plan|document)_.*/i }
		end
	end
end
