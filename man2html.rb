#!/usr/bin/env ruby -w


class Parser
	def initialize()
		@buffer = ""
		@p = false
		@af = true
		@ip = 0
		@lm = 0
		@rm = 0
		@name = ""
		@section = ""
		@date = ""
		@sh = nil


		@commands = {
			'.PP' => [:PP, 1],
			'.LM' => [:LM, 1],
			'.SH' => [:SH, 1],
			'.DA' => [:DA, 1],
			'.TH' => [:TH, 2],
			'.IP' => [:IP, 2],
			'.BR' => [:BR, 1],
			'.AF' => [:AF, 1],
			'.SP' => [:SP, 1],
			'.RC' => [:RC, 2],
			'.CN' => [:CN, 1],
		}


		@html_map =  {
			'<' => '&lt;',
			'>' => '&gt;', 
			'&' => '&amp;', 
			'...' => '&#8230;', 
			'``' => '&#8220;', 
			"''" => '&#8221;',
			'`' => '&#8216;',
			"'" => '&#8217;',
		}

	end

	def puts(x)
		return if x.nil?
		@buffer = @buffer + x.to_s + "\n"
	end	
	
	def print(x)
		return if x.nil?
		@buffer = @buffer + x.to_s
	end


	def header()
		puts <<-EOF
		<!DOCTYPE html>
		<html lang="en">
		<head>
		<meta charset="utf-8" />
		<title>#{@name}(#{@section})</title>

		<link rel="stylesheet" type="text/css" href="html.css" />
		</head>
		<body>
		<header></header>
		EOF

	end

	def footer()
		puts <<-EOF
		<footer></footer>
		</body>
		</html>
		EOF
	end


	def make_id(x)
		x.gsub(/\W+/, '_').downcase
	end


	def reformat(x)



		x = x.gsub(/(<|>|&)/, @html_map)

		return x unless @af

		# _ _ -> em or strong
		x = x.gsub(/_([^_]+)_/) {|m|
			m = $1
			if m.upcase == @name then
				"<strong>#{m}</strong>"
			else
				"<em>#{m}</em>"
			end
		}


		# ``...'' -> curly quotes + tt
		#x = x.gsub(/``(.*?)''/, '&#8220;<tt>\1</tt>&#8221;')

		# something path-like?
		x = x.gsub(/([\$][\/][A-Za-z0-9:\/.]*)/, '<tt>\1</tt>')

		x = x.gsub(/(``|''|\.\.\.|`|')/, @html_map)

		if @sh == "See Also"
			# help(C), manps(CT), manuals(F), whatis(CT)
			args = x.split(/,\s+/)
			begin
				args = args.map {|xx|
					raise "" unless xx =~ /^(\w+)\((\w+)\)$/
					"<a href=\"#{$2}/#{$1}.html\">#{xx}</a>"
				}	
				x = args.join(', ')		
			rescue Exception
				
			end
		end


		# ellipsis
		#x = x.gsub(/\.\.\./, '&#8230;')
		return x
	end

	def finish()

		end_block
		puts "</section>" if @sh
		@p = @sh = false
		@ip = 0
		@lm = 0
		@rm = 0
		footer

		# remove <p></p>
		@buffer.gsub!(/\<p\>\n*\<\/p\>/, '')
		return @buffer
	end


	def p()
		style = []
		lm = @ip + @lm
		style.push "margin-left: #{lm}ex;" if lm > 0
		style.push "margin-right: #{@rm}ex;" if @rm > 0
		print style.empty? ? "<p>" : "<p style=\"#{style.join(' ')}\">"

		@p = true
	end

	def end_block()
		puts "</pre>" unless @af
		puts "</p>" if @p
		puts "</div>" if @ip > 0
		@ip = 0
		@p = false
		@af = true
	end

	def process(line)
		line = line.strip
		return if line.empty?

		if line[0] == "."

			if line =~ /^(\.[A-Z]{2})(\s+)?(.*)/
				command = $1
				args = $3.strip
				xx = @commands[command] or raise "invalid command #{line}"
				fn, max_argc = xx
				argv = args.split(/\s+/, max_argc)

				send fn, argv
			else
				raise "Invalid command #{line}"
			end
		else
			puts reformat(line)
		end
	end

	def DA(argv)
		@date = argv[0] || ""
	end

	def TH(argv)
		@name, @section = argv
		header()
	end

	def PP(argv)
		end_block

		txt = argv[0]
		puts "<h2 class=\"PP\">#{reformat(txt)}</h2>" unless txt == "" || txt == nil
		p
	end

	def SH(argv)

		end_block
		puts "</section>" if @sh
		@lm = 0
		@rm = 0

		@sh = argv[0]
		puts "<section id=\"#{make_id(@sh)}\">"
		puts "<h1 class=\"SH\">#{reformat(@sh)}</h1>"
		p
	end


	def IP(argv)

		# .IP [n [s]]
		n, txt = argv
		end_block

		@ip = argv.size > 0 ? n.to_i : 0
		if @ip > 0 then
			puts "<div class=\"indent\">"
		end
		puts "<h2 class=\"IP\">#{reformat(txt)}</h2>" unless txt == "" || txt == nil
		p


	end


	def LM(argv)

		unless argv.empty?
			n = argv[0].to_i
			@lm = @lm + n
			puts "</p>" if @p
			p
		end
	end

	def RM(argv)
	end


	def CN(argv)
	end

	def BR(argv)
		n = argv.empty? ? 1 : argv[0].to_i
		puts "<br />" * n
	end

	def RC(argv)
		# .RC [n] char
		n = 1
		n = argv.shift.to_i if argv.size == 2 
		char = argv[0] || ''
		puts char * n
	end

	def AF(argv)

		x = argv.empty? ? !@af : argv[0].to_i > 0
		@af = x
		puts @af ? "</pre>" : "<pre>"

	end

	def SP(argv)
		# .SP [n]
		n = argv.empty? ? argv[0].to_i : '1'
		puts " " * n
	end


end




p = Parser.new


ARGF.each_line("\r") {|line|

	line.strip!

	next if line.empty?
	p.process(line)
}


puts p.finish()
