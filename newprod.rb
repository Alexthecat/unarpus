require_relative 'dependencies'
require_relative 'uniq_methods'

class App < Hobbit::Base
  include Hobbit::Session
  include Hobbit::Render
  include Hobbit::Filter
  use Rack::Session::Cookie, secret: 'hospital_fee',
                             expire_after: rand(300...10800)

  HOST = "http://#{Socket::gethostname}"

  before do
    set_user if check_auth && logged_in?
  end

  get '/forum/create-dir' do
    render 'land/newdir' if admin?
  end

  post '/forum/create-dir' do
    link = if request.params['link']=='';(0...50).map{('a'..'z').to_a[rand(26)]}.join;else;request.params['link'].gsub(' ','_');end
    FileUtils::mkdir_p("./data/forum/#{request.params['link'].gsub(' ','_')}")
    File.open("./data/forum/#{link}/index.txt", 'w'){|f|f.print"#{request.params['name']}*:*"}
    info = read_to_arr('forum/index')
    File.open('./data/forum/index.txt', 'w') do |f|
      info.each do |theme|
        f.print(if theme.split('*:*')[0]==request.params['where'];"#{theme.chomp}(-)#{link}***#{request.params['name']}\n";else;theme;end)
      end
    end
    response.redirect "#{HOST}/forum"
  end

  get '/forum/create' do
    @directories = Dir['./data/forum/*']
    @directories.delete('./data/forum/index.txt')
    render 'land/newtheme'
  end

  post '/forum/create' do
    land = "#{translate_to request.params['where']}/"
    link = if request.params['link'] == ''
             (0...50).map { ('a'..'z').to_a[rand(26)] }.join
           else
             request.params['link'].gsub(' ','_')
           end
    File.open("./data/forum/#{land}index.txt", 'a+') do |f|
      f.print '(-)' unless read_to_arr("forum/#{land}index")[0].split('*:*')[1].nil?
      f.print "#{land}#{link}***#{request.params['name']}"
    end
    File.open("./data/forum/#{land}#{link}.txt",'w'){|_|}
    response.redirect "#{HOST}/forum/#{translate_to request.params['where']}"
  end

  get '/forum/:land/:place/edit/:num/:login' do
    if admin? || @login.chomp == request.params[:login]
      @text = read_to_arr("forum/#{request.params[:land]}/#{request.params[:place]}")[request.params[:num].to_i - 1].split('*:*')[1]
      render 'land/editpost'
    end
  end

  post '/forum/:land/:place/edit/:num/:login' do
    if request.params['post'] != nil
      text = read_to_arr("forum/#{request.params[:land]}/#{request.params[:place]}")
      text[request.params[:num].to_i - 1].gsub!(text[request.params[:num].to_i - 1].split('*:*')[1], request.params['post'].gsub(/\n/, '|||'))
      text[request.params[:num].to_i - 1].gsub!(text[request.params[:num].to_i - 1].split('*:*')[2], "Отредактировано #{DateTime.now.strftime('%d.%m.%Y - %I:%M:%S')}")
      File.open("./data/forum/#{request.params[:land]}/#{request.params[:place]}.txt", 'w') {|f| text.each { |line| f.puts(from_forum_format(line.gsub(/\r/,'').gsub(/\n/,'|||'))) }}
      response.redirect "#{HOST}/forum/#{request.params[:land]}/#{request.params[:place]}/#{(request.params[:num].to_i/10).floor}"
    end
  end

  get '/forum/:land/:place/delete/:num/:login' do
    if admin? || @login.chomp == request.params[:login]
      info = read_to_arr("forum/#{request.params[:land]}/#{request.params[:place]}")
      info.delete(info[request.params[:num].to_i - 1])
      File.open("./data/forum/#{request.params[:land]}/#{request.params[:place]}.txt", 'w') do |f|
        info.each { |post| f.puts post }
      end
    end
    response.redirect request.env['HTTP_REFERER']
  end

  get '/forum/:land/:place/:name/delete' do
    if admin?
      File.delete("./data/forum/#{request.params[:land]}/#{request.params[:place]}.txt")
      name = to_rus(request.params[:name])
      ['forum/index', "forum/#{request.params[:land]}/index"].each do |location|
        info = read_to_arr(location)
        info.each do |line|
          %W((-)#{request.params[:land]}/#{request.params[:place]}***#{name} #{request.params[:land]}/#{request.params[:place]}***#{name}(-) #{request.params[:land]}/#{request.params[:place]}***#{name}).each do |reg|
            line.gsub!(reg, '')
          end
        end
        File.open("./data/#{location}.txt", 'w'){|f| info.each{|line| f.print line}}
      end
    end
    response.redirect "#{HOST}/forum/#{request.params[:land]}"
  end

  get '/forum/:dir/:name/delete' do
    if admin?
      FileUtils.rm_rf("./data/forum/#{request.params[:dir]}")
      name = to_rus(request.params[:name])
      info = read_to_arr('forum/index')
      info.each do |line|
        line.gsub!("(-)#{request.params[:dir]}***#{name}",'')
        line.gsub!("#{request.params[:dir]}***#{name}",'')
      end
      File.open('./data/forum/index.txt','w'){|f| info.each{|line| f.print(line)}}
    end
    response.redirect "#{HOST}/forum"
  end

  %w(/forum /forum/ /forum/:directory /forum/:directory/).each do |path|
    get path do
      dir   = "#{request.params[:directory]}/"
      @base = true if request.params[:directory].nil?
      @text = if read_to_arr("forum/#{dir}index")[0].split('*:*')[1].nil?
                File.open("./data/forum/#{request.params[:directory]}/1.txt",'w'){|_|}
                ["Пустой раздел*:*#{request.params[:directory]}/1***Данная тема не содержит в себе записей! Это запись, которую Каге должны удалить!"]
              else
                read_to_arr("forum/#{dir}index")
              end
      render 'land/forum'
    end
  end

  get '/forum/:land/:place' do
    response.redirect "#{HOST}/forum/#{request.params[:land]}/#{request.params[:place]}/0"
  end

  get '/forum/:land/:place/:start' do
    @text_info = Array.new
    @text_info.push(read_to_arr("forum/#{request.params[:land]}/#{request.params[:place]}"))
    @text_info.push(@text_info[0].size < 10 ? (0):(@text_info[0].size))
    @text_info.push(request.params[:start].to_i || 1)
    @text_info.push(if @text_info[1]<10;@text_info[0].size;elsif @text_info[1]-@text_info[2]*10<10;@text_info[1]-@text_info[2]*10;else;10;end)
    if (@text_info[2] > -1 && @text_info[2]*10+1 <= @text_info[1]) || request.params[:start] == '0'
      render 'land/land'
    else
      response.redirect "#{HOST}/forum/#{request.params[:land]}/#{request.params[:place]}/#{(@text_info[1]/10.0).floor}"
    end
  end

  post '/forum/:land/:place' do
    File.open("./data/forum/#{request.params[:land]}/#{request.params[:place]}.txt", 'a+') do |f|
      date = DateTime.now.strftime('%d.%m.%Y - %I:%M:%S')
      mess = from_forum_format(request.params['mess'].gsub(/\r/,'').gsub(/\n/,'|||'))
      f.puts "#{@login}(-)#{@image}(-)#{@rank}(-)#{@land}*:*#{mess}*:*#{date}"
    end if logged_in?
    response.redirect request.env['HTTP_REFERER']
  end

  get '/register' do
    logged_in? ? (response.redirect HOST):(render 'requests/register')
  end

  post '/register' do
    date  = DateTime.now.strftime('%d.%m.%Y - %I:%M:%S')
    login = request.params['login'].gsub!(' ','')
    if login && request.params['email'] && request.params['password'] && request.params['name'] && request.params['land'] && !File.read('./data/users.txt').include?(login) && !File.read('./data/users.txt').include?(request.params['email'])
      File.open('./data/users.txt','a+'){|f| f.puts "#{login}*:*#{request.params['password']}"}
      FileUtils::mkdir_p("./data/info/#{login}")
      File.open("./data/info/#{login}/#{login}.txt", 'w') do |f|
        f.puts "http://narufans.ru/images/avatars/no_avatar.gif*:*#{request.params['name']}*:*#{request.params['land']}*:*Генин*:*0*:*0*:*нет*:*нет*:*нет"
      end
      File.open("./data/info/#{login}/messages.txt", 'w') do |f|
        f.puts "Администрация*:*#{date}*:*Добро пожаловать на наш проект!*:*Мы рады приветствовать вас на нашем проекте ролевой игры по Наруто! От лица всей администрации хотелось бы поздравить вас с вашим вторым рождением. Только в нашей ролевой, вы погрузитесь в параллельную вселенную полную шиноби и крови!"
      end
      File.open("./data/info/#{login}/status.txt", 'w'){|f| f.puts '100*:*1000*:*100'}
      lands_info = read_to_arr('lands')
      num = case request.params['land'];when 'Конохагакуре';0;when 'Такигакуре';3;when 'Ямагакуре';2;else;1;end
      lands_info[num].gsub!(lands_info[num].split('*:*')[1], "#{lands_info[num].split('*:*')[1].to_i + 1}")
      File.open('./data/lands.txt', 'w'){|f| lands_info.each {|line| f.puts line}}
      response.redirect "#{HOST}/login"
    else
      render 'requests/register'
    end
  end

  get '/info/:login' do
    begin
      get_info(request.params[:login])
      get_stat(request.params[:login])
      get_diseases(request.params[:login])
      render 'personal/info'
    rescue
      response.status '404'
    end
  end

  get '/info/:login/edit' do
    if logged_in? && (admin? || @login == request.params[:login])
      get_info(request.params[:login])
      get_stat(request.params[:login])
      render 'personal/edit'
    end
  end

  post '/info/:login/edit' do
    info   = get_info(request.params[:login])
    result =  if info[9] == 'admin'
                "#{request.params['img']}*:*#{request.params['name']}*:*#{request.params['land']}*:*#{request.params['rank']}*:*#{request.params['money']}*:*#{info[5]}*:*#{request.params['bidju']}*:*#{request.params['kg']}*:*#{request.params['comrade']}*:*admin"
              elsif admin?
                "#{request.params['img']}*:*#{request.params['name']}*:*#{request.params['land']}*:*#{request.params['rank']}*:*#{request.params['money']}*:*#{info[5]}*:*#{request.params['bidju']}*:*#{request.params['kg']}*:*#{request.params['comrade']}"
              else
                "#{request.params['img']}*:*#{request.params['name']}*:*#{info[2]}*:*#{info[3]}*:*#{info[4]}*:*#{info[5]}*:*#{info[6]}*:*#{info[7]}*:*#{request.params['comrade']}"
              end
    File.open("./data/info/#{request.params[:login]}/status.txt", 'w') do |f|
      f.print "#{request.params['health']}*:*#{request.params['chakra']}*:*#{request.params['energy']}"
    end if admin?
    File.open("./data/info/#{request.params[:login]}/#{request.params[:login]}.txt", 'w'){|f| f.print result}
    response.redirect "#{HOST}/info/#{request.params[:login]}"
  end

  get '/info/:login/pm' do
    if logged_in? && @login.chomp == request.params[:login]
      @mess = read_to_arr("info/#{request.params[:login]}/messages")
      all_checked(@mess)
      render 'personal/pms'
    end
  end

  get '/info/:login/pm/:send_to' do
    logged_in?&&@login==request.params[:login] ? (render 'requests/send_pm_to'):(response.redirect HOST)
  end

  get '/info/:login/pm/:theme/:date/delete' do
    mess = read_to_arr("info/#{@login}/messages")
    mess.each{|m|mess.delete(m) if m.include?(to_rus request.params[:theme])&&m.include?(request.params[:date].gsub('%20',' '))}
    File.open("./data/info/#{@login}/messages.txt", 'w'){|f| mess.each {|m| f.puts m}}
    response.redirect "#{HOST}/info/#{request.params[:login]}/pm"
  end

  post '/info/:login/pm/:send_to' do
    date = DateTime.now.strftime('%d.%m.%Y - %I:%M:%S')
    File.open("./data/info/#{request.params[:send_to]}/messages.txt", 'a+') do |f|
      f.puts "((!))#{@login}*:*#{date}*:*#{request.params['subj']}*:*#{request.params['mess']}"
    end
    response.redirect "../../../../info/#{request.params[:send_to]}"
  end

  %w(/login /login/:err).each do |page|
    get page do
      if logged_in?
        response.redirect HOST
      else
        @error = 'Неверный логин или пароль!' unless request.params[:err].nil?
        render 'requests/login'
      end
    end
  end

  post '/login' do
    if read_to_arr('users').include?("#{request.params['login']}*:*#{request.params['password']}\n")
      logged_users = read_to_arr('logged')
      logged_users.each{|u| logged_users.delete(u) if u.include?(request.params['login'])}
      File.open('./data/logged.txt','w') do |f|
        logged_users.each{|u| f.puts(u)}
        f.puts "#{request.env['REMOTE_ADDR']}*:*#{request.params['login']}"
      end unless logged_in?
      response.redirect "#{HOST}/login"
    else
      response.redirect "#{HOST}/login/smthngwntwrng"
    end
  end

  get '/logout' do
    if logged_in?
      users = read_to_arr('logged')
      users.each{|user| users.delete(user) if user.chomp.split('*:*')[1] == @login.chomp}
      File.open('./data/logged.txt', 'w'){|f| users.each{|user| f.puts user.chomp}}
    end
    response.redirect HOST
  end

  get '/new' do
    render 'requests/new' if admin?
  end

  post '/new' do
    File.open('./data/index.txt','a+'){|f|f.puts"#{request.params['title']}*:*#{request.params['mess'].gsub(/\n/,'|||')}"}
    response.redirect HOST
  end

  get '/hospital' do
    get_diseases(@login) if logged_in?
    render 'hospital'
  end

  post '/hospital' do
    kind = request.params['kind']
    if kind == 'disease'
      cure_me(@login) if enough_money?(kind)
    else
      if enough_money?(kind)
        set_hp_to(convert(kind))
        session['hospital_fee'] = 'ok'
      end
    end
    response.redirect "#{HOST}/hospital"
  end

  get '/ichiraku' do
    render 'ichiraku'
  end

  post '/ichiraku' do
    if enough_money?(request.params['kind'])
      set_nrj_to(convert request.params['kind'])
      make_illness(gen_one(request.params['kind']))
    end
    response.redirect "#{HOST}/ichiraku"
  end

  %w(/ /:file_name).each do |path|
    get path do
      show_off(request.params[:file_name])
    end
  end
end