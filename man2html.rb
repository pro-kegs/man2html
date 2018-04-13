#!/usr/bin/env ruby -w


@buffer = ""


def puts(x)
	return if x.nil?
	@buffer = @buffer + x.to_s + "\n"
end

def print(x)
	return if x.nil?
	@buffer = @buffer + x.to_s
end


def header(name, section)
	puts <<-EOF
	<!DOCTYPE html>
	<html lang="en">
	<head>
	<meta charset="utf-8" />
	<title>#{name}(#{section})</title>

	<link rel="stylesheet" type="text/css" href="html.css" />
	</head>
	<body>
	EOF

end

def footer()
	puts <<-EOF
	</body>
	</html>
	EOF
end

def make_id(x)
	x.gsub(/\W+/, '_').downcase
end

def reformat(x, sh="", name = "")

	map =  { '<' => '&lt;', '>' => '&gt;', '&' => '&amp;', '...' => '&#8230;', '``' => '&#8220;', "''" => '&#8221;'} 
	x = x.gsub(/(<|>|&|``|''|\.\.\.)/, map)

	# _ _ -> em or strong
	x = x.gsub(/_([^_]+)_/) {|m|
		m = $1
		if m.upcase == name then
			"<strong>#{m}</strong>"
		else
			"<em>#{m}</em>"
		end
	}


	# ``...'' -> curly quotes + tt
	#x = x.gsub(/``(.*?)''/, '&#8220;<tt>\1</tt>&#8221;')

	# something path-like?
	x = x.gsub(/([\$][\/][A-Za-z0-9:\/.]*)/, '<tt>\1</tt>')

	x = x.gsub(/(``|''|\.\.\.)/, map)

	if sh == "See Also"
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


#map = {}
name = ""
section = ""
date = ""
sh = ""
af = true
ip = false
p = false
lm = 0
rm = 0


# command, (max) argument count
commands = {
	'.PP' => 1,
	'.LM' => 1,
	'.SH' => 1,
	'.DA' => 1,
	'.TH' => 2,
	'.IP' => 2,
	'.BR' => 1,
	'.AF' => 1,
	'.SP' => 1,
	'.RC' => 2,
	'.CN' => 1
}

ARGF.each_line("\r") {|line|

	line.strip!

	next if line.empty?

	if line[0] == '.' then
		if line =~ /^(\.[A-Z]{2})(\s+)?(.*)/
			command = $1
			args = $3.strip
			max_argc = commands[command] or raise "invalid command #{line}"
			argv = args.split(/\s+/, max_argc)

			case command
			when '.TH'
				name, section = argv
				header(name, section)

			when '.DA'
				date = argv[0] || ''

			when '.SH'
				puts "</p>" if p
				puts "</div>" if ip
				puts "</section>" if sh

				sh = argv[0]
				puts "<section id=\"#{make_id(sh)}\">"
				puts "<h1 class=\"SH\">#{reformat(sh)}</h1>"
				print "<p>"
				p = true
				ip = false

			when '.PP'
				puts "</p>" if p
				puts "</div>" if ip
				txt = argv[0]
				puts "<h2 class=\"PP\">#{reformat(txt)}</h2>" unless txt == "" || txt == nil
				print "<p>"
				ip = false
				p = true

			when '.IP'
				# .IP [n [s]]
				n, txt = argv
				puts "</p>" if p
				puts "</div>" if ip
				ip = false

				n = argv.size > 0 ? n.to_i : 0
				if n > 0 then
					puts "<div class=\"indent#{n}\">"
					ip = true
				end
				puts "<p class=\"ip\">#{reformat(txt)}</p>" unless txt == "" || txt == nil
				print "<p>"
				p = true

			when '.BR'
				n = argv.empty? ? 1 : argv[0].to_i
				puts "<br />" * n

			when '.AF'
				if argv.empty? then
					af = !af
				else
					af = argv[0].to_i > 0
				end
				puts af ? "</pre>" : "<pre>"

			when '.SP'
				# .SP [n]
				n = argv.empty? ? argv[0].to_i : '1'
				puts " " * n

			when '.RC'
				# .RC [n] char
				n = 1
				n = argv.shift.to_i if argv.size == 2 
				char = argv[0] || ''
				puts char * n


			when '.LM'
				unless argv.empty?
					n = argv[0].to_i
					lm = lm + n
					puts "</p>" if p
					print lm == 0 ? "<p>" : "<p style=\"margin-left: #{lm}ex;\">"
					p = true
				end
			when '.RM'
				# todo ...
				rm = 0



			else
				raise "invalid command #{line}"
			end
			next
		end
		raise "invalid command #{line}"
	end

	puts reformat(line, sh, name)
}
puts "</p>" if p
puts "</div>" if ip
puts "</section>" if sh
footer


@buffer.gsub!(/\<p\>\n*\<\/p\>/, '')
$stdout.puts @buffer
