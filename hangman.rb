# def read_txt_file()
#   File.open("google-10000-english-no-swears.txt", "r") do |file|
#     file.each {|line| puts line.length}
#   end
# end

# read_txt_file()

require 'yaml'
require 'json'

module Serializable
  def save_to_yaml(filename)
    # Create saves directory if it doesn't exist
    Dir.mkdir("saves") unless Dir.exist?("saves")

    File.open("saves/#{filename}.yaml", "w") do |file|
      file.write(YAML.dump(self))
    end
    puts "Game saved as #{filename}.yaml!"
  end

  def save_to_json(filename)
    Dir.mkdir("saves") unless Dir.exist?("saves")

    # Convert data to hash
    game_data = self.to_hash

    File.open("saves/#{filename}.json", "w") do |file|
      file.write(JSON.pretty_generate(game_data))
    end
    puts "Game saves as #{filename}.json!"
  end

  # Class methods to load the data
  def self.load_from_yaml(filename)
    return nil unless File.exist?("saves/#{filename}.yaml")

    File.open("saves/#{filename}.yaml", "r") do |file|
      YAML.load(file.read, permitted_classes: [Game, Player, Board, Word])
    end
  end

  def self.load_from_json(filename, game_class)
    return nil unless File.exist?("saves/#{filename}.json")

    File.open("saves/#{filename}.json", "r") do |file|
      data = JSON.parse(file.read)
      game_class.from_hash(data)
    end
  end
end

class Word
  def initialize
    @words = []
  end

  def load_dictionary()
    File.open("google-10000-english-no-swears.txt", "r") do |file|
      file.each do |line|
        word = line.chomp
        @words << word if word.length.between?(5, 12)
      end
    end
    @words
  end

  def random_word
    @words.sample
  end
end

class Player
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def make_guess
    puts "#{@name}, enter your guess: "
    gets.chomp.upcase
  end
end

class Board
  attr_reader :secret_word, :display_word, :wrong_guesses, :guesses_left, :all_guessed_letters

  def initialize(secret_word, max_guesses = 6)
    @secret_word = secret_word.upcase.chars # So that it's already broken up into letters
    @display_word = Array.new(@secret_word.length, "_")
    @wrong_guesses = []
    @all_guessed_letters = []               # Track all letters that have been guessed.
    @guesses_left = max_guesses
  end

  def already_guessed?(letter)
    @all_guessed_letters ||= []
    @all_guessed_letters.include?(letter)
  end

  def update_board(letter)
    @all_guessed_letters << letter

    if @secret_word.include?(letter)
      @secret_word.each_with_index do |char, index|
        @display_word[index] = char if char == letter
      end
      true  # Return true for correct guess
    else
      @wrong_guesses << letter unless @wrong_guesses.include?(letter)
      @guesses_left -= 1
      false # Return false for wrong guess
    end
  end

  def display
    puts "\n" + "="*40
    puts "Word: " + @display_word.join(" ")
    puts "Wrong guesses: " + (@wrong_guesses.empty? ? "None" : @wrong_guesses.join(", "))
    puts "Guesses left: #{@guesses_left}"
    puts "="*40 + "\n"
  end

  def word_complete?
    !@display_word.include?("_")
  end

  def out_of_guesses?
    @guesses_left <= 0
  end

  # Method to recreate board state from saved data
  def self.from_data(secret_word, display_word, wrong_guesses, guesses_left, all_guessed_letters = [])
    board = allocate    # To create object without calling initialize since we want to recreate data
    board.instance_variable_set(:@secret_word, secret_word)
    board.instance_variable_set(:@display_word, display_word)
    board.instance_variable_set(:@wrong_guesses, wrong_guesses)
    board.instance_variable_set(:@guesses_left, guesses_left)
    board.instance_variable_set(:@all_guessed_letters, all_guessed_letters || [])
    board
  end
end

class Game
  include Serializable

  def initialize(player_name = nil)
    @word_manager = Word.new
    @word_manager.load_dictionary

    if player_name
      @player = Player.new(player_name)
      @board = Board.new(@word_manager.random_word)
      @game_active = true
    end
  end

  # Main game loop
  def play
    puts "Welcome to Hangman!"

    # For new game
    unless @player
      puts "Enter your name: "
      player_name = gets.chomp
      @player = Player.new(player_name)
      @board = Board.new(@word_manager.random_word)
      @game_active = true
    end

    puts "Let's play, #{@player.name}!"

    # Loop continues until game ends
    while @game_active
      @board.display

      # Check win/lose before asking for input
      if @board.word_complete?
        puts "Congratulations #{@player.name}! You won!"
        @game_active = false
        next
      end

      if @board.out_of_guesses?
        puts "Game Over! The word was: #{@board.secret_word.join('')}"
        @game_active = false
        next
      end

      # Streamlined input - one prompt to handle saving and guessing
      puts "Enter a letter to guess, or type 'save' to save your game:"
      input = gets.chomp.upcase

      if input.downcase == "save"
        handle_save
        next    # Continues game after saving
      end

      if input.length != 1 || !input.match?(/[A-Z]/)
        puts "Please enter a single letter or 'save' to save your game!"
        next
      end

      if @board.already_guessed?(input)
        puts "You already guessed '#{input}'! Try a different letter."
        next
      end

      # Update board and give feedback
      if @board.update_board(input)
        puts "Good guess!"
      else
        puts "Sorry, '#{input}' is not in the word."
      end
    end

    play_again?
  end

  # Handles the save process - allows user to choose format and filename
  def handle_save
    puts "Choose save format:"
    puts "1. YAML"
    puts "2. JSON"
    puts "Enter choice (1 or 2): "

    format_choice = gets.chomp

    print "Enter filename (without extension): "
    filename = gets.chomp

    case format_choice
    when "1"
        save_to_yaml(filename)
    when "2"
        save_to_json(filename)
    else
        puts "Invalid choice. Game not saved."
    end
  end

  # Convert game state to hash for JSON serialization
  def to_hash
    {
        player_name: @player.name,
        secret_word: @board.secret_word,
        display_word: @board.display_word,
        wrong_guesses: @board.wrong_guesses,
        all_guessed_letters: @board.all_guessed_letters,
        guesses_left: @board.guesses_left,
        game_active: @game_active
    }
  end

  # Create game from hash data (for JSON loading)
  def self.from_hash(data)
    game = allocate

    # Recreate game data
    word_manager = Word.new
    word_manager.load_dictionary
    game.instance_variable_set(:@word_manager, word_manager)

    game.instance_variable_set(:@player, Player.new(data['player_name']))
    game.instance_variable_set(:@board, Board.from_data(
        data['secret_word'],
        data['display_word'],
        data['wrong_guesses'],
        data['guesses_left'],
        data['all_guessed_letters'] || []   # Default to empty array for old game save compatibility
    ))
    game.instance_variable_set(:@game_active, data['game_active'])

    game
  end

  def play_again?
    puts "\nWould you like to play again? (y/n): "
    choice = gets.chomp.downcase

    if choice == "y" || choice == "yes"
      new_game = Game.new(@player.name)
      new_game.play
    else
      puts "Thanks for playing!"
    end
  end

  # Class method to show main menu and handle game loading
  def self.start_game
    puts "HANGMAN!"
    puts "="*20
    puts "1. New Game"
    puts "2. Load Saved Game"
    puts "3. Quit"
    print "Choose an option: "

    choice = gets.chomp

    case choice
    when "1"
        game = Game.new
        game.play
    when "2"
        load_game
    when "3"
        puts "Goodbye!"
    else
        puts "Invalid choice!"
        start_game
    end
  end

  def self.load_game
    # Cgheck if save directory exists
    unless Dir.exist?("saves")
      puts "No saved games found!"
      start_game
      return
    end

    # List available save files
    save_files = Dir.entries("saves").select { |file| file.end_with?(".yaml", ".json") }

    if save_files.empty?
      puts "No saved games found!"
      start_game
      return
    end

    puts "\nSaved Games:"
    save_files.each_with_index do |file, index|
      puts "#{index + 1}. #{file}"
    end

    print "Enter the number of the game to load: "
    file_index = gets.chomp.to_i - 1

    if file_index < 0 || file_index >= save_files.length
      puts "Invalid selection!"
      load_game
      return
    end

    selected_file = save_files[file_index]
    filename = selected_file.sub(/\.(yaml|json)$/, "")

    loaded_game = if selected_file.end_with?(".yaml")
                    Serializable.load_from_yaml(filename)
                  else
                    Serializable.load_from_json(filename, Game)
                  end

    if loaded_game
        puts "Game loaded successfully!"
        loaded_game.play
    else
        puts "Failed to load game!"
        start_game
    end
  end
end

Game.start_game