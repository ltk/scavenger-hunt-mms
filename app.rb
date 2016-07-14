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
  @pending_texts = []
  @ronin_number = ENV['RONIN_NUMBER']
  @client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
  if params[:error].nil?
    @error = false
  else
    @error = true
  end

end

set :static, true

# CLUES

# IN
# remote battery compartment
# disney vhs
# bear canister
# bike


# green goji
# you don't need to go
# to dushanbe to find the
# my favorite green


# ring recepticle

# OUT


# Lunch rez at Oak
# find a gold star
# enter some word in the scene
# free-for-all answer (server's name, price of a cookie + tax (before tip))

# kaia goose chase (you may find a start in the scene of the most recent wild goose chase)
# bike (bring your lock!)
# south boulder animal hospital (name of a front desk person) [louise|shellee|janice]
# under the sun (cost of a cookie)
# king soopers (the basil olive oil code)
# house where I left my sunglasses
# ncar (TKTKTK something from trailhead sign... maybe how many stations there are in the nature walk thing?)
# magic mesa
# teahouse (how many kinds of tea do they have)
# T-aco ()
# rio grande (You got the bad kind. )
# amu
# luciles (all digits on their front door) [7282]
# mountain sun (drink and FY, then text me your server's name)
# The laughing goat ()
# whole foods (mochi fridge)
# solana
# sanitas brewery
# motomaki
# jimmy johns (how many tables are there?)
# ethiopian place


# Non-Shared Places
# Oak
# Arabesque
# champions center
# old office?



# Flagstaff (enter the number of pedal strokes it takes you to get here... jk)



# Home

# 1 Sledding in Tantra Park
# 2 South Boulder Animal hospital
# 3 RTD Park and Ride
# __ transfer  __
# 4 Old Viget Office
# 5 Dushanbe Teahouse
# 6 Boulder Tubing Park
# 7 Settlers Park (Red Rocks)
# 8 Lolita's Market
# 9 Centro
# 10 Amu
# 11 Luciles
# 12 Mountain Sun (Lunch + Beer)
# 13 Laughing Goat
# 14 Whole Foods
# 15 Solana
# 16 Crossfit Sanitas
# 17 Champions Center
# 18 CU Law
# 19 Ras Kassas
# 20 Creekside Elementary
# 21 Neptune
# 22 Under the Sun

# Home


# Spruce pool?
# mr horse
# birdies



$CLUES = {
  "clue1" => {
    "keyword" => /ball|tree/,
    "title" => %q(
you don't need to go
to dushanbe to find the
my favorite green
    )
  },
  "clue2" => {
    "keyword" => /ball|tree/,
    "title" => %q(
we power the thing
you use to give power to
a much bigger thing
    )
  },
  "clue3" => {
    "keyword" => 'mermaid',
    "title" => %q(
seeing will make you
think twice about surf and turf
Lawson wouldn't know
    )
  },
  "clue4" => {
    "keyword" => 'vault',
    "title" => %q(
The first words of this
poem don't really matter.
Jenny can't get in.
    )
  },
  "clue5" => {
    "keyword" => 'meep',
    "title" => %q(
mommy! mommy! meep!
we want to go out and play!
meep! meep! meep! mommy!
    )
  },
  "clue6" => {
    "keyword" => 'bca',
    "title" => %q(
omg find them
but first you need to find me
then move in a spiral
    )
  },
  "clue7" => {
    "keyword" => 'yes',
    "title" => %q(
Candle-gripping star
spares are deposited here.
well, what do you say?
    )
  },
  "clue8" => {
    "keyword" => 'giant',
    "title" => %q(
expensive new toy
picturesque sunset vistas
downhill is scary
    )
  },
  "clue9" => {
    "keyword" => 'vasque',
    "title" => %q(
my dirt is a sign
of the beatings I've taken
to bring you nature
    )
  },
  "clue10" => {
    "keyword" => 'goose',
    "title" => %q(
you may find a star
in the scene of an actual,
real life wild goose chase
    )
  },
  "clue11" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(

    )
  },
  "clue12" => {
    "keyword" => 'TKTKTKTKT',
    "title" => %q(

    )
  },
  # 1 Sledding in Tantra Park
  "clue13" => {
    "keyword" => 'TKTKTKTK',
    "title" => %q(
Plastic in garage
Put to its intended use
Watch out for that hay!
    )
  },
  # 2 South Boulder Animal hospital
  "clue14" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(
sick pumpkin muffin
was feeling a lot better
after a visit
    )
  },
  # 3 RTD Park and Ride
  "clue15" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(
despite what it says
tou don't have to park to ride
to airport or work
    )
  },
  # 4 Old Viget Office
  "clue16" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(
back alley dealings
aka another day
at old Viget west
    )
  },
  # 5 Dushanbe Teahouse
  "clue17" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(
It sucks that all we
gave in return was a lame
internet cafe
    )
  },
  # 6 Boulder Tubing Park
  "clue18" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(
started our float here
if you can call it a float
more like survival
    )
  },
  # 7 Settlers Park (Red Rocks)
  # Rock climbing in work attire.
  "clue19" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(

    )
  },
  # 8 Lolita's Market
  # 24 hour market, snozwitches
  "clue20" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(

    )
  },
  # 9 Centro
  # puts the "fun" in fundido
  # mojitos
  "clue21" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(

    )
  },
  # 10 Amu
  "clue22" => {
    "keyword" => 'TKTKTKTKT',
    "title" => %q(
ahem, no shoes here
find a different place to wear
shoes on your birthdays
    )
  },
  # 11 Luciles
  "clue23" => {
    "keyword" => 'TKTKTKTK',
    "title" => %q(
Goodness gracious me.
I can't fit another bite.
Too much carbs to start.
    )
  },
  # 12 Mountain Sun (Lunch + Beer)
  "clue24" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(
Proceed to water hole
after one or two FYs
a star may appear
    )
  },
  # 13 Laughing Goat
  "clue25" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(
hip cafe named for
an epic badass of the
mountain wilderness
    )
  },
  # 14 Whole Foods
  "clue26" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(
where in the hell is
the tandoori masala
check every bottle
    )
  },
  # 15 Solana
  "clue27" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(
Is there a word for
the opposite of fung shui?
That's what they went for.
    )
  },
  # 16 Crossfit Sanitas
  "clue28" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(
do you ever get
to push those huge tires around?
think outside the box
    )
  },
  # 17 Champions Center
  # hit me with that sweet
  # radi
  # PT starts wednesday.
  "clue29" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(

    )
  },
  # 18 CU Law
  "clue30" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(

    )
  },
  # 19 Ras Kassas
  "clue31" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(
elastic or food?
rang the bell, rang it again
anybody home?
    )
  },
  # 20 Creekside Elementary
  "clue32" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(
4803
if we bought it, J-K kids
would go to learn here
    )
  },
  # 21 Neptune
  "clue33" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(

    )
  },
  # 22 Under the Sun
  "clue34" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(

    )
  },
  # Next clue back at home
  "clue35" => {
    "keyword" => 'TKTKTKT',
    "title" => %q(

    )
  },
}

get '/scavenger/?' do
  puts "new message"
  puts params
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
      denied = ["no", "na", "nope", "no way", "nah", "dont", "don't", "not"].include?(@body)

      if denied
        output = "Ummm... really? You sure, cuz everyone seems to think you do. Don't you like scavenger hunts?"
        @player.update(:status => 'reconfirming')
      else
        puts "Sending #{@player.name} a clue."
        output = "Cool! Well then it's time for your first clue! I'll send it in a sec. Find the thing, then text me the code word on or around it."
        @player.update(:status => 'hunting')
        sendNextClue(@player)
      end

    when :reconfirming
      denied = ["no", "na", "nope", "no way", "nah", "dont", "don't", "not"].include?(@body)

      if denied
        output = "Well this is embarassing. Are you willing to do a scavenger hunt anyway?"
        @player.update(:status => 'reconfirming')
      else
        puts "Sending #{@player.name} a clue."
        output = "Cool! Well then it's time for your first clue! I'll send it in a sec. Find the thing, then text me the code word on or around it."
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
      puts "remaining #{remaining}"

      if @body =~ clue['keyword']

        # Score this point
        # complete = @player.complete++

        # Remove the clue that was just completed
        remaining.delete(current)

        # UPDATE THE USER
        @player.update(:remaining => remaining.join(','))

        if remaining.length == 0
          output = "Congratulations #{@player.name}! You've finished the hunt and found #{@player.complete} clues! You finished in #{@minutes}! Ur cool."
        else
          success_messages = [
            "Nailed it.",
            "Dayum you're smart #{@player.name}.",
            "Yup, right on.",
            "Well done #{@player.name}!",
            "Niiiiiice!",
            "Sweeeet!",
            "Booyah.",
            "You got it... is this too easy?",
            "Perfect!",
            "Correcto.",
            "Uh huh!",
          ]

          output = "#{success_messages.sample} Now, onto the next clue!"

          # Get next clue and send it.
          sendNextClue(@player)
        end

      else
        # Player missed one, increment
        # puts @player.missed
        # missed = @player.missed++
        # @player.update(:missed => missed)

        output = "That's not completely right (in fact it's wrong). Try again. Or I guess you could ask for a hint."

        # Get next clue and send it.
        # sendNextClue(@player)
      end
    end
  rescue StandardError => e
    puts @player
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

  # @send_this = nil
  #
  # if params['SmsSid'] == nil
  #   return @send_this
  # else
  #   response = Twilio::TwiML::Response.new do |r|
  #     r.Sms output
  #   end
  #   @send_this = response.text
  # end
  #
  # sleep 1

  # @send_this


  @client.account.messages.create({
    to:  @phone_number,
    from: ENV['RONIN_NUMBER'],
    body: output
  })

  send_pending_texts

  200
end

def send_pending_texts
  @pending_texts.each do |text|
    test_params = text.merge({ from: ENV['RONIN_NUMBER'] })
    @client.account.messages.create(test_params)
  end

  @pending_texts = []
end

def sendNextClue(user)
  remaining = user.remaining
  remaining = remaining.split(',')

  next_clue = remaining[0]

  clue = $CLUES[next_clue]

  # sendPicture(@phone_number, clue['title'], clue['url'])
  sendPicture(@phone_number, clue['title'])

  @player.update(:current => next_clue)
end

def sendPicture(to, message)
  @pending_texts.push({
    to:  @phone_number,
    body: message
  })
  # message = @client.account.messages.create(
  #   :from => ENV['RONIN_NUMBER'],
  #   :to => @phone_number,
  #   :body => msg,
  #   # :media_url => media,
  # )
  # puts message.to
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
