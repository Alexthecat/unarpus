def show_off(fn)
  fn  = 'index' if fn.nil?
  if File.exist?("./data/#{fn}.txt")
    @text = read_to_arr("#{fn}")
    @num  = @text.length
    render 'index'
  else
    response.status '404'
  end
end
def check_auth
  File.read('./data/logged.txt').each_line do |line|
    ip=request.env['REMOTE_ADDR']
    split=line.split('*:*')
    if split[0] == (ip)
      @authorized=true
      @login=split[1].chomp
    end
  end
end
def read_to_arr(what);arr=Array.new;File.read("./data/#{what}.txt").each_line{|line| arr.push(line)};arr;end
def logged_in?;if @authorized;true;else;false;end;end
def admin?;true if @rank=='Каге'||(@authorized&&read_to_arr("info/#{@login}/#{@login}")[0].split('*:*')[9]=='admin');end
def set_user
  info      = read_to_arr("info/#{@login}/#{@login}")[0].split('*:*')
  status    = read_to_arr("info/#{@login}/status")[0].split('*:*')
  @url      = "/info/#{@login}"; @image = info[0]
  @nickname = info[1]; @land  = info[2];   @rank     = info[3]; @money   = info[4]
  @attitude = info[5]; @bidju = info[6];   @kg       = info[7]; @comrade = info[8]
  @chakra   = status[1]; @hp  = status[0]; @energy   = status[2]
  @eng_land = translate_to(@land)
end
def check_pm
  num = 0
  read_to_arr("info/#{@login}/messages").each { |message| num+=1 if message.include?('((!))') }
  "(#{num})"
end
def check_online(login)
  online = false; read_to_arr('logged').each {|l| online = true if l.include?(login)}
  if online
    'http://upload.wikimedia.org/wikipedia/commons/thumb/0/0e/Ski_trail_rating_symbol-green_circle.svg/600px-Ski_trail_rating_symbol-green_circle.svg.png'
  else
    'http://www.clker.com/cliparts/5/P/4/j/w/t/glossy-green-circle-button-hi.png'
  end
end
def all_checked(me);me.each{|m|m.gsub!('((!))','')};File.open("./data/info/#{@login}/messages.txt",'w'){|f|me.each{|a|f.puts a}};end
def get_info(who);@info=read_to_arr("info/#{who}/#{who}")[0].split('*:*');end
def get_stat(who);@stat=read_to_arr("info/#{who}/status")[0].split('*:*');end
def to_rus(string);URI::unescape(string).force_encoding('UTF-8').chomp;end
def to_rus_name(string)
  read_to_arr('forum/index').each do |line|
    line.split('*:*').each do |l|
      if l.include?('(-)')
        l.split('(-)').each do |theme|
          if theme.split('***')[0] == string.split('/')[3] && theme.split('***')[1] == 'Улицы деревни'
            return "#{theme.split('***')[1]}(#{string.split('/')[3]})"
          elsif theme.split('***')[0] == string.split('/')[3]
            return theme.split('***')[1]
          end
        end
      else
        return l.split('***')[1] if l.split('***')[0] == string.split('/')[3]
      end
    end
  end
end
def translate_to(what)
  if what    == 'Коноха'  || what == 'Деревня скрытой Листвы'
    'konoha'
  elsif what == 'Песок'   || what == 'Деревня скрытого Песка'
    'suna'
  elsif what == 'Вулкан'  || what == 'Деревня скрытого Вулкана'
    'oto'
  elsif what == 'Водопад' || what == 'Деревня скрытого Водопада'
    'tsuchi'
  elsif what == 'Общее'
    'common'
  elsif what == 'Акацуки'
    'akatsuki'
  else
    what
  end
end
def rank_img(rank)
  if    rank == 'Каге' || rank == 'Саннин'
    'http://anime-naruto.ucoz.kz/r/SA.png'
  elsif rank == 'Джонин'
    'http://anime-naruto.ucoz.kz/r/J.png'
  elsif rank == 'Чуунин'
    'http://anime-naruto.ucoz.kz/r/C.png'
  elsif rank == 'Генин'
    'http://anime-naruto.ucoz.kz/r/G.png'
  else
    'http://anime-naruto.ucoz.kz/Grup/user.png'
  end
end
def from_forum_format(string)
  from  = [/\r\n/, /\n/, /\r/, '[img]', '[/img]', '[i]', '[/i]', '[b]', '[/b]', '[u]', '[/u]', '[/color]']
  to    = ['|||', '|||', '|||', '<img style="max-height: 300px;" src="', '"/>', '<i>', '</i>', '<b>', '</b>', '<u>', '</u>', '</span>']
  (0..from.length-1).each{|i| string.gsub!("#{from[i]}", "#{to[i]}")}
  string.scan(/color=.{3,6}/).each do |col|
    string.gsub!("[color=#{col.split('=')[1]}]", "<span style='color:##{col.split('=')[1]}'>")
  end if string.scan(/color=.{3,6}/) != []
  string
end
def back_to_forum_format(string)
  to    = [/\n/, '[img]', '[/img]', '[i]', '[/i]', '[b]', '[/b]', '[u]', '[/u]', '[/color]']
  from  = ['|||', '<img style="max-height: 300px;" src="', '"/>', '<i>', '</i>', '<b>', '</b>', '<u>', '</u>', '</span>']
  (0..from.length-1).each{|i| string.gsub!("#{from[i]}", "#{to[i]}")}
  string.scan(/color:#.{3,6}/).each do |col|
    string.gsub!("<span style='color:##{col.split('#')[1]}'>", "[color=#{col.split('#')[1]}]")
  end if string.scan(/color:#.{3,6}/) != []
  string
end
# Hospital Methods
def convert(str);case str;when'small';10;when'medium';40;when'normal';20;when'big';85;when'bigfood';29;when'superfood';50;when'enormous';100;else;0;end;end
def set_hp_to(num)
  status = read_to_arr("info/#{@login}/status")[0]
  if @hp.to_i + num.to_i >= 100
    status.gsub!(status.split('*:*')[0],'100')
  else
    status.gsub!(status.split('*:*')[0],"#{@hp.to_i + num.to_i}")
  end
  File.open("./data/info/#{@login}/status.txt",'w'){|f| f.print status}
end
def set_nrj_to(num)
  status = read_to_arr("info/#{@login}/status")[0]
  if @energy.to_i + num.to_i >= 100
    status.gsub!(status.split('*:*')[2],'100')
  else
    status.gsub!(status.split('*:*')[2],"#{@energy.to_i + num.to_i}")
  end
  File.open("./data/info/#{@login}/status.txt",'w'){|f| f.print status}
end
def enough_money?(money)
  sum=case money;when'small';75;when'medium';300;when'normal';120;when'bigfood';185;when'superfood';210;when'big';600;when'disease';350;else;1000;end
  if @money.to_i >= sum
    get_info(@login)
    @info[4].gsub!("#{@info[4]}", "#{@money.to_i-sum.to_i}")
    File.open("./data/info/#{@login}/#{@login}.txt",'w') do |l|
      if @info[9] == 'admin'
        l.print "#{@info[0]}*:*#{@info[1]}*:*#{@info[2]}*:*#{@info[3]}*:*#{@info[4]}*:*#{@info[5]}*:*#{@info[6]}*:*#{@info[7]}*:*#{@info[8]}*:*admin"
      else
        l.print "#{@info[0]}*:*#{@info[1]}*:*#{@info[2]}*:*#{@info[3]}*:*#{@info[4]}*:*#{@info[5]}*:*#{@info[6]}*:*#{@info[7]}*:*#{@info[8]}"
      end
    end
    true
  else
    false
  end
end
# Diseases
def gen_one(kind)
  chance = case kind;when'small';60;when'normal';75;when'bigfood';87;else;93;end
  rand(0...chance) <= 100 - chance ? (read_to_arr('diseases').sample.chomp):(nil)
end
def get_diseases(who)
  @diseases=read_to_arr("info/#{who}/diseases")
  unless @diseases.nil?
    @diseases.each do |illness|
      @diseases.delete(illness) unless (Time.now - Time.parse(illness.split('(-)')[1].chomp))/3600 < 24 || illness.split('(-)')[0] != ''
    end
    File.open("./data/info/#{who}/diseases.txt",'w'){|f| @diseases.each{|ill| f.puts ill}}
    @diseases.each{|illness|illness.gsub!("(-)#{illness.split('(-)')[1]}",'')}
    @diseases.uniq!
    @diseases.each{|illness|@diseases.delete(illness) if illness == ''}
  end
  @diseases
end
def make_illness(disease)
  illness_history = read_to_arr("info/#{@login}/diseases")
  illness_history.each{|ill| ill.gsub!("(-)#{ill.split('(-)')[1]}",'')}
  File.open("./data/info/#{@login}/diseases.txt",'a+'){|f|f.puts"#{disease}(-)#{Time.now}"} unless disease.nil? && illness_history.include?(disease)
end
def cure_me(who)
  list = read_to_arr("info/#{who}/diseases")
  unless list.nil?
    num  = rand(0...list.size-1) || 0
    list.each{|illness| list.delete(illness) if illness.include?(list[num].split('(-)')[0])}
    File.open("./data/info/#{who}/diseases.txt",'w'){|f|list.each{|dis|f.puts dis}}
  end
end