#!/usr/bin/env ruby -w


class Parser
	def initialize()
		@buffer = ""
		@p = false
		@af = true
		@ip = 0
		@lm = 0
		@rm = 0
		@tb = false
		@name = ""
		@section = ""
		@date = ""
		@sh = nil


		@commands = {
			'.PP' => [:PP, 1],
			'.LM' => [:LM, 1],
			'.RM' => [:RM, 1],
			'.SH' => [:SH, 1],
			'.DA' => [:DA, 1],
			'.TH' => [:TH, 2],
			'.IP' => [:IP, 2],
			'.BR' => [:BR, 1],
			'.AF' => [:AF, 1],
			'.SP' => [:SP, 1],
			'.RC' => [:RC, 2],
			#'.CN' => [:CN, 1],
			'.IF' => [:IF, 1],
			'.NP' => [:NP, 0],
			'.TB' => [:TB, 1],
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
			"--" => '&#8212;',
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
		<style>#{IO.read("man2html.css")}</style>
		</head>
		<body>
		<header></header>
		EOF

#		<link rel="stylesheet" type="text/css" href="html.css" />
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


		x = x.gsub(/(``|''|\.\.\.|`|'|--)/, @html_map)


		if @sh == "Files" && x =~ /-/
			args = x.split(/\s+-\s+/, 2)
			args.each {|xx| xx.strip! }

			x = "<dl><dt><tt>#{args[0]}</tt></dt><dd>#{args[1]}</dd></dl>"

		else
			# something path-like?
			x = x.gsub(/([\$][\/][A-Za-z0-9:\/.]*)/, '<tt>\1</tt>')
		end

		if @sh == "See Also"
			# help(C), manps(CT), manuals(F), whatis(CT)
			args = x.split(/,\s+/)
			begin
				args = args.map {|xx|
					raise "" unless xx =~ /^([A-Za-z][A-Za-z0-9.]+)\((\w+)\)$/
					"<a href=\"/man.#{$2}/#{$1}.html\">#{xx}</a>"
				}	
				x = args.join(', ')		
			rescue Exception
				
			end
		end


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

		# merge adjacent dl lists.
		@buffer.gsub!(/\<\/dl\>\n*\<dl\>/, "\n")
		@buffer.gsub!(/\<\/dl\>\n*\<br \/\>\n*\<dl\>/, "\n")
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
		puts "</tt>" unless @af
		puts '</span>' if @tb
		puts "</p>" if @p
		puts "</div>" if @ip > 0
		@ip = 0
		@p = false
		@af = true
		@tb = false
	end

	def process(line)
		line = line.rstrip
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
		unless argv.empty?
			n = argv[0].to_i
			@rm = @rm - n
			puts "</p>" if @p
			p
		end
	end


	def CN(argv)
	end

	def IF(argv)
		# .IF n
		# if < n lines remaining on page, do a .NP
		# ignored.
	end

	def NP(argv)
		#.NP
		# New Page
	end

	def BR(argv)
		n = argv.empty? ? 1 : argv[0].to_i

		if @tb
			puts '</span>'
			@tb = false
			if @p then
				puts '</p>'
				p
			end
		else
			puts "<br />" * n
		end
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
		puts @af ? '</tt>' : '<tt class="pre">'

	end

	def SP(argv)
		# .SP [n]
		n = argv.empty? ? 1 : argv[0].to_i
		puts " " * n
	end


	def TB(argv)
		# .TB n
		n = argv[0].to_i
		puts '</span>' if @tb
		style = "left: #{n}ex; display: inline-block; position: absolute;"
		print "<span style=\"#{style}\">"
		@tb = true
	end

end




p = Parser.new


ARGF.each_line {|line| p.process(line) }


puts p.finish()
