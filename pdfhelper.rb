#!/usr/bin/env ruby
# pdfhelper.rb - Wrapper interactif pour pdftk
# Installation : chmod +x pdfhelper.rb && sudo cp pdfhelper.rb /usr/local/bin/pdfhelper

require 'readline'

# ─── Couleurs ────────────────────────────────────────────────────────────────
def c(code, text) = "\e[#{code}m#{text}\e[0m"
def bold(t)   = c(1, t)
def cyan(t)   = c(36, t)
def green(t)  = c(32, t)
def yellow(t) = c(33, t)
def red(t)    = c(31, t)
def gray(t)   = c(90, t)

# ─── Quoting des chemins ─────────────────────────────────────────────────────
# On entoure chaque chemin de guillemets simples dans la commande shell.
# Les apostrophes dans le chemin sont gérées avec la séquence '\'' .
def q(path)
  "'" + path.to_s.gsub("'", "'\\''") + "'"
end

# ─── Utilitaires ─────────────────────────────────────────────────────────────
def check_pdftk
  unless system('which pdftk > /dev/null 2>&1')
    puts red("✗ pdftk n'est pas installé.")
    puts gray("  -> sudo apt install pdftk   (Debian/Ubuntu)")
    puts gray("  -> brew install pdftk-java  (macOS)")
    exit 1
  end
end

# ─── Autocomplétion ──────────────────────────────────────────────────────────
# Problème de base : Readline coupe l'input sur l'espace, donc un chemin comme
# "Cours Informatique/foo.pdf" arrive tronqué au completion_proc.
# Solution : on retire l'espace de completer_word_break_characters, comme ça
# le chemin complet (espaces inclus) est transmis intact.

def setup_completion(pdf_only: false)
  Readline.completion_append_character     = ''
  Readline.completer_word_break_characters = "\t\n\"\\'><=;|&{("
  Readline.completer_quote_characters      = '"'

  Readline.completion_proc = proc do |input|
    raw = input.to_s

    if raw.empty?
      dir    = Dir.pwd
      prefix = ''
      base   = ''
    elsif raw.end_with?('/')
      dir    = File.expand_path(raw)
      prefix = ''
      base   = raw
    else
      expanded = File.expand_path(raw)
      dir      = File.dirname(expanded)
      prefix   = File.basename(raw)
      slash    = raw.rindex('/')
      base     = slash ? raw[0..slash] : ''
    end

    entries = begin
      Dir.entries(dir).reject { |e| e.start_with?('.') }
    rescue Errno::ENOENT
      []
    end

    entries.filter_map do |entry|
      next unless entry.downcase.start_with?(prefix.downcase)

      full      = File.join(dir, entry)
      completed = "#{base}#{entry}"

      if File.directory?(full)
        "#{completed}/"
      elsif !pdf_only || entry.downcase.end_with?('.pdf')
        completed
      end
    end.sort
  end
end

def ask(prompt, default: nil, pdf_only: false)
  setup_completion(pdf_only: pdf_only)
  hint  = default ? gray(" [#{default}]") : ''
  label = "  #{cyan('>')} #{prompt}#{hint} : "

  input = Readline.readline(label, true)
  return default if input.nil? || input.strip.empty?
  input.strip
end

def confirm(prompt)
  Readline.completion_proc = proc { [] }
  input = Readline.readline("  #{yellow('?')} #{prompt} #{gray('[o/N]')} : ", false)
  input&.strip&.downcase == 'o'
end

def pdf?(path)
  path.end_with?('.pdf') && File.exist?(path)
end

def require_pdf(label = 'Fichier PDF')
  loop do
    path = ask(label, pdf_only: true)
    return nil if path.nil? || path.strip.empty?
    path = File.expand_path(path.strip)
    return path if pdf?(path)
    puts red("  ✗ Fichier introuvable ou pas un PDF : #{path}")
  end
end

def run(cmd)
  puts "\n" + gray("  $ #{cmd}")
  result = system(cmd)
  puts result ? green('  ✓ Succes') : red('  ✗ Erreur lors de l\'execution')
  result
end

# ─── Menu ────────────────────────────────────────────────────────────────────
OPERATIONS = {
  '1' => { label: 'Fusionner des PDFs',              method: :op_merge    },
  '2' => { label: 'Extraire des pages',              method: :op_extract  },
  '3' => { label: 'Diviser en pages individuelles',  method: :op_burst    },
  '4' => { label: 'Faire pivoter des pages',         method: :op_rotate   },
  '5' => { label: 'Chiffrer un PDF',                 method: :op_encrypt  },
  '6' => { label: 'Dechiffrer un PDF',               method: :op_decrypt  },
  '7' => { label: 'Informations sur un PDF',         method: :op_info     },
  '8' => { label: 'Compresser un PDF',               method: :op_compress },
  '9' => { label: 'Assembler (interleave) 2 PDFs',   method: :op_shuffle  },
  'q' => { label: 'Quitter',                         method: nil          }
}.freeze

def show_menu
  puts
  puts bold('  +==============================+')
  puts bold("  |     #{cyan('PDF Helper')} -- pdftk      |")
  puts bold('  +==============================+')
  puts
  OPERATIONS.each do |key, op|
    next if key == 'q'
    puts "  #{yellow(key)}. #{op[:label]}"
  end
  puts "  #{yellow('q')}. Quitter"
  puts
end

# ─── Operations ──────────────────────────────────────────────────────────────

def op_merge
  puts bold("\n  -- Fusion de PDFs --")
  puts gray("  Ajoute les PDFs un par un. Entree vide pour arreter.\n")

  inputs = []
  index  = 1

  loop do
    puts
    path = require_pdf("PDF n#{index} (entree vide pour terminer)")
    break if path.nil?

    pages = ask('Pages a inclure (ex: 1-3, 5, 8-end)', default: 'all')
    pages = 'all' if pages.nil? || pages.strip.empty?

    handle = ('A'.ord + index - 1).chr
    inputs << { handle: handle, path: path, pages: pages }
    puts green("  + Ajoute : #{File.basename(path)} -- pages : #{pages}")
    index += 1
  end

  if inputs.size < 2
    puts yellow('  Besoin d\'au moins 2 fichiers pour fusionner.')
    return
  end

  output = ask('Fichier de sortie', default: 'merged.pdf')
  output += '.pdf' unless output.end_with?('.pdf')

  handles_def = inputs.map { |i| "#{i[:handle]}=#{q(i[:path])}" }.join(' ')
  cat_args    = inputs.map { |i| i[:pages] == 'all' ? i[:handle] : "#{i[:handle]}#{i[:pages]}" }.join(' ')

  run("pdftk #{handles_def} cat #{cat_args} output #{q(output)}")
end

def op_extract
  puts bold("\n  -- Extraction de pages --")

  input = require_pdf('Fichier source')
  return unless input

  pages  = ask('Pages a extraire (ex: 1-3, 5, 8-end)', default: '1-end')
  output = ask('Fichier de sortie', default: 'extracted.pdf')
  output += '.pdf' unless output.end_with?('.pdf')

  run("pdftk #{q(input)} cat #{pages} output #{q(output)}")
end

def op_burst
  puts bold("\n  -- Division en pages individuelles --")

  input  = require_pdf('Fichier a diviser')
  return unless input

  prefix = ask('Prefixe des fichiers generes', default: 'page_%04d.pdf')
  puts gray("  Les fichiers seront crees dans : #{File.dirname(File.expand_path(prefix))}")

  run("pdftk #{q(input)} burst output #{q(prefix)}")
end

ROTATIONS = {
  '1' => 'north',
  '2' => 'east',
  '3' => 'south',
  '4' => 'west'
}.freeze

def op_rotate
  puts bold("\n  -- Rotation de pages --")

  input = require_pdf('Fichier source')
  return unless input

  puts
  puts '  Sens de rotation :'
  puts "  #{yellow('1')}. 0   (north -- aucun changement)"
  puts "  #{yellow('2')}. 90  (east  -- horaire)"
  puts "  #{yellow('3')}. 180 (south)"
  puts "  #{yellow('4')}. 270 (west  -- anti-horaire)"
  puts

  rot = ROTATIONS[ask('Choix')]
  unless rot
    puts red('  Choix invalide.')
    return
  end

  pages  = ask('Pages a faire pivoter (ex: 1-3, end, 1-end)', default: '1-end')
  output = ask('Fichier de sortie', default: 'rotated.pdf')
  output += '.pdf' unless output.end_with?('.pdf')

  run("pdftk #{q(input)} cat #{pages}#{rot} output #{q(output)}")
end

def op_encrypt
  puts bold("\n  -- Chiffrement --")

  input = require_pdf('Fichier a chiffrer')
  return unless input

  puts '  Niveau de chiffrement :'
  puts "  #{yellow('1')}. 128 bits (defaut)"
  puts "  #{yellow('2')}. 40 bits (legacy)"
  enc = ask('Choix', default: '1') == '2' ? '40bit' : '128bit'

  print "  #{cyan('>')} Mot de passe utilisateur (lecture) : "
  user_pw = gets&.chomp
  print "  #{cyan('>')} Mot de passe proprietaire (modif)  : "
  owner_pw = gets&.chomp

  output = ask('Fichier de sortie', default: 'encrypted.pdf')
  output += '.pdf' unless output.end_with?('.pdf')

  cmd  = "pdftk #{q(input)} output #{q(output)} encrypt_#{enc}"
  cmd += " user_pw #{q(user_pw)}"   unless user_pw.to_s.empty?
  cmd += " owner_pw #{q(owner_pw)}" unless owner_pw.to_s.empty?
  run(cmd)
end

def op_decrypt
  puts bold("\n  -- Dechiffrement --")

  input = require_pdf('Fichier chiffre')
  return unless input

  print "  #{cyan('>')} Mot de passe : "
  pw = gets&.chomp

  output = ask('Fichier de sortie', default: 'decrypted.pdf')
  output += '.pdf' unless output.end_with?('.pdf')

  run("pdftk #{q(input)} input_pw #{q(pw)} output #{q(output)}")
end

def op_info
  puts bold("\n  -- Informations sur un PDF --")

  input = require_pdf('Fichier PDF')
  return unless input

  run("pdftk #{q(input)} dump_data")
end

def op_compress
  puts bold("\n  -- Compression --")

  input = require_pdf('Fichier a compresser')
  return unless input

  output = ask('Fichier de sortie', default: 'compressed.pdf')
  output += '.pdf' unless output.end_with?('.pdf')

  run("pdftk #{q(input)} output #{q(output)} compress")
end

def op_shuffle
  puts bold("\n  -- Assemblage interleave (recto/verso) --")
  puts gray("  Utile pour recombiner un scan recto et un scan verso.\n")

  input_a = require_pdf('PDF recto (pages impaires)')
  return unless input_a

  input_b = require_pdf('PDF verso (pages paires, ordre inverse)')
  return unless input_b

  output = ask('Fichier de sortie', default: 'interleaved.pdf')
  output += '.pdf' unless output.end_with?('.pdf')

  run("pdftk A=#{q(input_a)} B=#{q(input_b)} shuffle A Bend-1 output #{q(output)}")
end

# ─── Point d'entree ──────────────────────────────────────────────────────────
check_pdftk

loop do
  show_menu
  Readline.completion_proc = proc { [] }
  choice = Readline.readline("  #{bold('Choix')} : ", false)&.strip&.downcase

  if choice == 'q' || choice.nil?
    puts "\n" + gray('  A plus tard.')
    break
  end

  op = OPERATIONS[choice]
  if op.nil?
    puts red('  Choix invalide.')
    next
  end

  send(op[:method])

  puts
  unless confirm('Effectuer une autre operation ?')
    puts gray("\n  A plus tard.")
    break
  end
end