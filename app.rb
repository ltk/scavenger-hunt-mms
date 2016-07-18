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

$CLUES = {
  "clue1" => {
    "keyword" => /disney|disneys|disney's/,
    "title" => %q(
seeing will make you
think twice about surf and turf
Lawson wouldn't know
    )
  },
  "clue2" => {
    "keyword" => /ball/,
    "title" => %q(
you don't need to go
to dushanbe to find the
my favorite green
    )
  },
  "clue3" => {
    "keyword" =>/tracker2/,
    "title" => %q(
omg find them!
but first you need to find me
then move in a spiral
    )
  },
  "clue4" => {
    "keyword" => /sony/,
    "title" => %q(
we power the thing
you use to give power to
a much bigger thing
    )
  },
  "clue5" => {
    "keyword" => /other/,
    "title" => %q(
the first words of this
poem don't really matter.
Jenny can't get in.
    )
  },
  "clue6" => {
    "keyword" => /meep!?/,
    "title" => %q(
mommy! mommy! meep!
we want to go out and play!
meep! meep! meep! mommy!
    )
  },
  "clue7" => {
    "keyword" => /vasque/,
    "title" => %q(
my dirt is a sign
of the beatings I've taken
to bring you nature
    )
  },
  "clue8" => {
    "keyword" => /pull/,
    "title" => %q(
you may find a star
in the scene of an actual,
real life wild goose chase
    )
  },
  "clue9" => {
    "keyword" => /giant/,
    "title" => %q(
expensive new toy
picturesque sunset vistas
downhill is scary
    )
  },
  "clue10" => {
    "keyword" => /.*/,
    "title" => %q(
plastic in garage
put to its intended use
watch out for that hay!
    )
  },
  "clue11" => {
    "keyword" => /entrance|bite/,
    "title" => %q(
sick pumpkin muffin
was feeling a lot better
after a visit
    )
  },
  "clue12" => {
    "keyword" => /kiss/,
    "title" => %q(
despite what it says
you don't have to park to ride
to airport or work
    )
  },
  "clue13" => {
    "keyword" => /fire/,
    "title" => %q(
back alley dealings
aka another day
at old Viget west
    )
  },
  "clue14" => {
    "keyword" => /market/,
    "title" => %q(
veggies, pasta, cheese
come find it all at this place
which isn’t open
    )
  },
  "clue15" => {
    "keyword" => /area/,
    "title" => %q(
started our float here
if you can call it a float
more like survival
    )
  },
  "clue16" => {
    "keyword" => /gold/,
    "title" => %q(
red rock rock climbing
in work attire of course
go take a picture
    )
  },
  "clue17" => {
    "keyword" => /juice/,
    "title" => %q(
man it’s hot outside
grab a beverage from this shop
open all the time
    )
  },
  "clue18" => {
    "keyword" => /towed/,
    "title" => %q(
surrounded by fear
the only place nearby where
zoe feels at home
    )
  },
  "clue19" => {
    "keyword" => /glass/,
    "title" => %q(
ahem, no shoes here
find a different place to wear
shoes on your birthdays
    )
  },
  "clue20" => {
    "keyword" => /camera/,
    "title" => %q(
goodness gracious me.
I can't fit another bite.
too much carbs to start.
    )
  },
  "clue21" => {
    "keyword" => /.*/,
    "title" => %q(
pause the video
after one or two FYs
a star may appear
    )
  },
  "clue22" => {
    "keyword" => /8|eight/,
    "title" => %q(
want to make a splash?
I hear there’s a spot nearby
text number of lanes
    )
  },
  "clue23" => {
    "keyword" => /cove|365/,
    "title" => %q(
you fetched it before
obscure item for sushi
go fetch it again
    )
  },
  "clue24" => {
    "keyword" => /pay/,
    "title" => %q(
Is there a word for
the opposite of fung shui?
That's what they went for.
    )
  },
  "clue25" => {
    "keyword" => /crossfit/,
    "title" => %q(
do you ever get
to push those huge tires around?
think outside the box
    )
  },
  "clue28" => {
    "keyword" => /bell/,
    "title" => %q(
elastic or food?
rang the bell, rang it again
anybody home?
    )
  },
  "clue29" => {
    "keyword" => /success/,
    "title" => %q(
4803
if we bought it, J-K kids
would go learn here first
    )
  },
  "clue30" => {
    "keyword" => /denali/,
    "title" => %q(
next to Uranus,
find a route to the top of
Lawson’s bucket list
    )
  },
  "clue31" => {
    "keyword" => /trash/,
    "title" => %q(
cash-only cookies
that aint gonna work for us
without a stop here
    )
  },
  "clue31.5" => {
    "keyword" => /.*/,
    "title" => %q(
woah, you're flush with cash!
know a good place to spend it?
text me the total
    )
  },
  "clue32" => {
    "keyword" => /protein/,
    "title" => %q(
chemically speaking,
I keep your kittens alive.
or should I say cats?
    )
  },
  "clue33" => {
    "keyword" => /austin/,
    "title" => %q(
my name is not ed.
I watch you during dinner.
come flip me over.
    )
  },
  "clue34" => {
    "keyword" => /846[- ]?qzz/,
    "title" => %q(
mountainous weekends
wouldn't happen without me

    )
  },
  "clue35" => {
    "keyword" => /forever/,
    "title" => %q(
today you might find
something other than toe socks
in the toe sock’s home
    )
  },
  "clue36" => {
    "keyword" => /yes!*/,
    "title" => %q(
candle-gripping star
spares are deposited here.
well, what do you say?
    )
  }
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
        output = "Cool! Do you also like gold stars? Of course you do, so it's time for your first clue! I'll send it in a sec. Find the star, then text me the starred word!"
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
          output = "🙂🙂😙😜😃🎈🎉🎂 Yay!! Ur cool."
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
        fail_messages = [
          "Not quite. Try something else.",
          "Sorry #{@player.name}. That's wrong.",
          "Nope, keep trying.",
          "Close but no cigar.",
          "Shoot, not exactly.",
          "Argh, that's not right.",
          "Ugh, that's not it. Try again?",
          "Keep trying! Not quite there yet though.",
          ":-( Negative. Try again.",
        ]

        output = fail_messages.sample
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
