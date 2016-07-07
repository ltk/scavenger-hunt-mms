require "bundler/setup"
require "sinatra"
require "data_mapper"
require "twilio-ruby"
require "sanitize"
require "haml"

# Using DataMapper for our psql data manager
DataMapper::Logger.new(STDOUT, :debug)
DataMapper::setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/scavenge')

class Player
  include DataMapper::Resource

  property :id, Serial
  property :phone_number, String, :length => 30, :required => true
  property :name, String
  property :current, String
  property :status, Enum[ :new, :naming, :hunting, :confirming, :reconfirming], :default => :new
  property :missed, Integer, :default => 0
  property :complete, Integer, :default => 0
  property :remaining, Object

end

DataMapper.finalize
DataMapper.auto_upgrade!

# Load up our necessary requirements before each function
before do
  @ronin_number = ENV['RONIN_NUMBER']
  @client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
  if params[:error].nil?
    @error = false
  else
    @error = true
  end

end

set :static, true

$CLUES = {
  "clue1" => {
    "keyword" => 'boygeorge',
    "title" => 'Humdinger of a clue',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue01.jpg'
  },
  "clue2" => {
    "keyword" => 'scumbucket',
    "title" => 'Let this clue float in your head for a bit.',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue02.jpg'
  },
  "clue3" => {
    "keyword" => 'billieidol',
    "title" => 'Wood you be my neighbor?',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue03.jpg'
  },
  "clue4" => {
    "keyword" => 'erasure',
    "title" => 'Time to hunt!',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue04.jpg'
  },
  "clue5" => {
    "keyword" => 'blondie',
    "title" => 'Can you handle this?',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue05.jpg'
  },
  "clue6" => {
    "keyword" => 'cinderella',
    "title" => 'Your days are numbered...',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue06.jpg'
  },
  "clue7" => {
    "keyword" => 'joejackson',
    "title" => 'Your inability to find these clues is grating on me.',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue07.jpg'
  },
  "clue8" => {
    "keyword" => 'onedirection',
    "title" => 'Your progress is a bad sign.',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue08.jpg'
  },
  "clue9" => {
    "keyword" => 'wildfire',
    "title" => 'Wash away your fears',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue09.jpg'
  },
  "clue10" => {
    "keyword" => 'slowmo',
    "title" => 'Are you getting tired of this?',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue10.jpg'
  },
  "clue11" => {
    "keyword" => 'dummy',
    "title" => 'The wicked clue is dead?',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue11.jpg'
  },
  "clue12" => {
    "keyword" => 'fakeplastic',
    "title" => 'Rock on dude!',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue12.jpg'
  },
  "clue13" => {
    "keyword" => 'menatwork',
    "title" => 'Keep looking!',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue13.jpg'
  },
  "clue14" => {
    "keyword" => 'duran',
    "title" => 'Dont lean on your senses.',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue14.jpg'
  },
  "clue15" => {
    "keyword" => 'jazzyjeff',
    "title" => 'Let cooler heads prevail.',
    "url" => 'https://dl.dropboxusercontent.com/u/123971/scavenger-hunt/clue15.jpg'
  },
}

get '/scavenger/?' do
  # Decide what do based on status and body
  @phone_number = Sanitize.clean(params[:From])
  @body = params[:Body].downcase

  # Find the player associated with this number if there is one
  @player = Player.first(:phone_number => @phone_number)

  # if the user doesn't exist create a new user.
  if @player.nil?
    @player = createUser(@phone_number)
  end

  begin
    # this is our main game trigger, depending on users status in the game, respond appropriately
    status = @player.status

    # switch based on 'where' in the game the user is.
    case status

    # Setup the player details
    when :new
      output = "Hey Wendy! HAPPY BIRTHDAY! I heard you like scavenger hunts. Is that true?"
      @player.update(:status => 'confirming')

    when :confirming
      denied = ["no", "na", "nope", "no way", "nah"].include?(@body)

      if !denied
        output = "Ummm... really? You sure, cuz everyone seems to think you do. Don't you like scavenger hunts?"
        @player.update(:status => 'reconfirming')
      else
        puts "Sending #{@player.name} a clue."
        output = "Cool! Well then it's time to go find your first clue! I'll send you picture of it shortly. Once you solve the clue and find the thing, find the code word on or around it and text it to me."
        @player.update(:status => 'hunting')
        sendNextClue(@player)
      end

    when :reconfirming
      denied = ["no", "na", "nope", "no way", "nah"].include?(@body)

      if !denied
        output = "Well this is embarassing. Are you willing to do a scavenger hunt anyway?"
        @player.update(:status => 'reconfirming')
      else
        puts "Sending #{@player.name} a clue."
        output = "Cool! Well then it's time to go find your first clue! You should receive a picture of it shortly. Once you find the object send back the word clue to this number."
        @player.update(:status => 'hunting')
        sendNextClue(@player)
      end

    # Get Player NickName
    # when :naming
    #   if @player.name.nil?
    #     @player.name = @body
    #     @player.save
    #     output = "We have your nickname as #{@body}. Is this correct? [yes] or [no]?"
    #   else
    #     if @body == 'yes'
    #       puts "Sending #{@player.name} a clue."
    #       output = "Ok #{@player.name}, time to go find your first clue! You should receive a picture of it shortly. Once you find the object send back the word clue to this number."
    #       @player.update(:status => 'hunting')
    #       sendNextClue(@player)
    #     else
    #       output = "Okay safari dude. What is your nickname then?"
    #       @player.update(:name => nil)
    #     end
    #   end

    # When the user is hunting
    when :hunting
      currentTime = Time.now
      # check what the current clue is
      current = @player.current
      clue = $CLUES[current]

      # Turn the remaining object into a proper array, to remove
      # the correct clue from it later.
      remaining = (@player.remaining).split(',')

      if @body == clue['keyword']

        # Score this point
        complete = @player.complete++

        # Remove the clue that was just completed
        remaining.delete(current)

        # UPDATE THE USER
        @player.update(:complete => complete, :remaining => remaining.join(','))

        if remaining.length == 0
          output = "Congratulations #{@player.name}! You've finished the game and found #{@player.complete} clues! Your fastest time was #{@minutes}, which is pretty good! Now just wait for the others to finish and a special rewards ceremony."
        else
          output = "Well done #{@player.name}! You've just found a treasure! Now here's the next clue!"

          # Get next clue and send it.
          sendNextClue(@player)
        end

      else
        # Player missed one, increment
        missed = @player.missed++
        @player.update(:missed => missed)

        output = "That's not completely right (in fact it's wrong). Here's another clue, see if you can find it."

        # Get next clue and send it.
        sendNextClue(@player)
      end
    end
  rescue StandardError => e
    puts e.inspect
    puts e.backtrace

    output = "Oh noes! Something bad happened and my computer brain is terribly confused. I just texted Lawson asking him to fix me. He'll try to get this sorted out."

    # Send a text to the game runner to check-in on the app. Something broke
    # this main function.
    message = @client.account.messages.create(
      :from => ENV['RONIN_NUMBER'],
      :to => ENV['PERSONAL_PHONE'],
      :body => "Something went wrong with WSJK. Check the logs and figure out what happened. The phone that hit the error was #{@player.phone_number}."
    )
  end

  if params['SmsSid'] == nil
    return nil
  else
    response = Twilio::TwiML::Response.new do |r|
      r.Sms output
    end
    response.text
  end
end

def sendNextClue(user)
  remaining = user.remaining
  remaining = remaining.split(',')

  l = remaining.length
  next_clue = remaining[rand(l)]

  clue = $CLUES[next_clue]

  sendPicture(@phone_number, clue['title'], clue['url'])

  @player.update(:current => next_clue)
end

def sendPicture(to, msg, media)
  message = @client.account.messages.create(
    :from => ENV['RONIN_NUMBER'],
    :to => @phone_number,
    :body => msg,
    :media_url => media,
  )
  puts message.to
end

def createUser(phone_number)
  clues = ($CLUES.keys).join(',')
  user = Player.create(
    :phone_number => phone_number,
    :remaining => clues,
    :name => "Wendy",
  )
  user.save
  return user
end

get "/" do
  haml :index
end

get '/users/?' do
  @players = Player.all
  haml :users
end
