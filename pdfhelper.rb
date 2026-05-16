#!/usr/bin/env ruby
# pdfhelper.rb - Wrapper interactif pour pdftk
# Installation : chmod +x pdfhelper.rb && sudo cp pdfhelper.rb /usr/local/bin/pdfhelper

require 'readline'
require 'tempfile'

COLOR = {
  red:    "\033[1;31m",
  green:  "\033[1;32m",
  yellow: "\033[1;33m",
  blue:   "\033[1;34m",
  cyan:   "\033[1;36m",
  purple: "\033[1;35m",
  nc:     "\033[0m"
}

# Affiche un texte coloré dans le terminal.
#
# @param color [Symbol] clé de la constante COLOR (:red, :green, :yellow, ...)
# @param text  [String] texte à afficher
def my_puts(color, text)
  puts "#{COLOR[color]}#{text}#{COLOR[:nc]}"
end

# Entoure un chemin de guillemets simples pour l'usage en shell.
# Les apostrophes dans le chemin sont gérées proprement.
#
# @param path [String] chemin à protéger
# @return [String] chemin entre guillemets simples
def shell_quote(path)
  "'" + path.to_s.gsub("'", "'\\''") + "'"
end

# Vérifie que pdftk est bien installé, sinon on arrête tout.
def check_pdftk
  return if system('which pdftk > /dev/null 2>&1')

  my_puts(:red, "✗ pdftk n'est pas installé.")
  puts "#{COLOR[:nc]}  -> sudo apt install pdftk   (Debian/Ubuntu)"
  puts "  -> brew install pdftk-java  (macOS)"
  exit 1
end

# Configure l'autocomplétion Readline pour les chemins de fichiers.
# On retire l'espace des word_break_characters pour gérer les chemins
# avec espaces (ex: "Mes Documents/truc.pdf").
#
# @param pdf_only [Boolean] si true, ne complète que les fichiers .pdf
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

# Affiche un prompt et lit la saisie utilisateur avec autocomplétion.
#
# @param prompt   [String]  texte du prompt
# @param default  [String]  valeur retournée si l'utilisateur valide sans saisir
# @param pdf_only [Boolean] restreindre la complétion aux .pdf
# @return [String, nil]
def ask(prompt, default: nil, pdf_only: false)
  setup_completion(pdf_only: pdf_only)
  hint  = default ? " #{COLOR[:nc]}[#{default}]" : ''
  label = "  #{COLOR[:cyan]}>#{COLOR[:nc]} #{prompt}#{hint} : "

  input = Readline.readline(label, true)
  return default if input.nil? || input.strip.empty?
  input.strip
end

# Pose une question oui/non à l'utilisateur.
#
# @param prompt [String] texte de la question
# @return [Boolean]
def confirm(prompt)
  Readline.completion_proc = proc { [] }
  input = Readline.readline("  #{COLOR[:yellow]}?#{COLOR[:nc]} #{prompt} #{COLOR[:nc]}[o/N] : ", false)
  input&.strip&.downcase == 'o'
end

# Vérifie qu'un chemin pointe vers un fichier PDF existant.
def valid_pdf?(path)
  path.end_with?('.pdf') && File.exist?(path)
end

# Demande un chemin PDF valide, en rebouclant tant que ce n'est pas bon.
#
# @param label [String] texte du prompt
# @return [String, nil] chemin absolu du PDF, ou nil si l'utilisateur ne saisit rien
def require_pdf(label = 'Fichier PDF')
  loop do
    path = ask(label, pdf_only: true)
    return nil if path.nil? || path.strip.empty?

    path = File.expand_path(path.strip)
    return path if valid_pdf?(path)

    my_puts(:red, "  ✗ Fichier introuvable ou pas un PDF : #{path}")
  end
end

# Exécute une commande shell et affiche le résultat.
#
# @param cmd [String] commande à exécuter
# @return [Boolean] true si succès
def run(cmd)
  puts "\n#{COLOR[:nc]}  $ #{cmd}"
  result = system(cmd)
  result ? my_puts(:green, '  ✓ Succès') : my_puts(:red, "  ✗ Erreur lors de l'exécution")
  result
end

# Injecte les métadonnées Creator/Producer dans un PDF via pdftk update_info.
# Le fichier de sortie est modifié sur place.
#
# @param output_path [String] chemin du PDF à modifier
# @param author      [String] valeur à mettre dans Creator et Producer
def set_pdf_metadata(output_path, author: 'Pdfhelper in Ruby by Nael')
  meta = Tempfile.new(['pdfmeta', '.txt'])
  meta.write("InfoBegin\nInfoKey: Creator\nInfoValue: #{author}\n")
  meta.write("InfoBegin\nInfoKey: Producer\nInfoValue: #{author}\n")
  meta.close

  tmp = output_path + '.meta_tmp.pdf'
  ok  = system("pdftk #{shell_quote(output_path)} update_info #{shell_quote(meta.path)} output #{shell_quote(tmp)}")

  if ok && File.exist?(tmp)
    File.rename(tmp, output_path)
    my_puts(:cyan, '  ✓ Métadonnées mises à jour')
  else
    my_puts(:yellow, '  ⚠ Impossible de mettre à jour les métadonnées')
    File.delete(tmp) if File.exist?(tmp)
  end
ensure
  meta&.unlink
end

# Wrapper autour de run : exécute la commande puis applique les métadonnées
# si la commande a réussi et qu'un fichier de sortie est fourni.
#
# @param cmd         [String] commande shell à exécuter
# @param output_path [String, nil] chemin du fichier produit
def run_with_metadata(cmd, output_path = nil)
  return unless run(cmd)
  set_pdf_metadata(output_path) if output_path && File.exist?(output_path)
end

# Opérations 

def op_merge
  my_puts(:blue, "\n  -- Fusion de PDFs --")
  puts "  Ajoute les PDFs un par un. Entrée vide pour arrêter.\n"

  inputs = []
  index  = 1

  loop do
    puts
    path = require_pdf("PDF n#{index} (entrée vide pour terminer)")
    break if path.nil?

    pages = ask('Pages à inclure (ex: 1-3, 5, 8-end)', default: 'all')
    pages = 'all' if pages.nil? || pages.strip.empty?

    handle = ('A'.ord + index - 1).chr
    inputs << { handle: handle, path: path, pages: pages }
    my_puts(:green, "  + Ajouté : #{File.basename(path)} -- pages : #{pages}")
    index += 1
  end

  if inputs.size < 2
    my_puts(:yellow, "  Besoin d'au moins 2 fichiers pour fusionner.")
    return
  end

  output = ask('Fichier de sortie', default: 'merged.pdf')
  output += '.pdf' unless output.end_with?('.pdf')

  handles_def = inputs.map { |i| "#{i[:handle]}=#{shell_quote(i[:path])}" }.join(' ')
  cat_args    = inputs.map { |i| i[:pages] == 'all' ? i[:handle] : "#{i[:handle]}#{i[:pages]}" }.join(' ')

  run_with_metadata("pdftk #{handles_def} cat #{cat_args} output #{shell_quote(output)}", output)
end

def op_extract
  my_puts(:blue, "\n  -- Extraction de pages --")

  input = require_pdf('Fichier source')
  return unless input

  pages  = ask('Pages à extraire (ex: 1-3, 5, 8-end)', default: '1-end')
  output = ask('Fichier de sortie', default: 'extracted.pdf')
  output += '.pdf' unless output.end_with?('.pdf')

  run_with_metadata("pdftk #{shell_quote(input)} cat #{pages} output #{shell_quote(output)}", output)
end

def op_burst
  my_puts(:blue, "\n  -- Division en pages individuelles --")

  input  = require_pdf('Fichier à diviser')
  return unless input

  prefix = ask('Préfixe des fichiers générés', default: 'page_%04d.pdf')
  puts "  Les fichiers seront créés dans : #{File.dirname(File.expand_path(prefix))}"

  # burst ne produit pas un seul fichier de sortie, pas de métadonnées ici
  run("pdftk #{shell_quote(input)} burst output #{shell_quote(prefix)}")
end

ROTATIONS = {
  '1' => 'north',
  '2' => 'east',
  '3' => 'south',
  '4' => 'west'
}.freeze

def op_rotate
  my_puts(:blue, "\n  -- Rotation de pages --")

  input = require_pdf('Fichier source')
  return unless input

  puts
  puts '  Sens de rotation :'
  puts "  #{COLOR[:yellow]}1#{COLOR[:nc]}. 0   (north -- aucun changement)"
  puts "  #{COLOR[:yellow]}2#{COLOR[:nc]}. 90  (east  -- horaire)"
  puts "  #{COLOR[:yellow]}3#{COLOR[:nc]}. 180 (south)"
  puts "  #{COLOR[:yellow]}4#{COLOR[:nc]}. 270 (west  -- anti-horaire)"
  puts

  rot = ROTATIONS[ask('Choix')]
  unless rot
    my_puts(:red, '  Choix invalide.')
    return
  end

  pages  = ask('Pages à faire pivoter (ex: 1-3, end, 1-end)', default: '1-end')
  output = ask('Fichier de sortie', default: 'rotated.pdf')
  output += '.pdf' unless output.end_with?('.pdf')

  run_with_metadata("pdftk #{shell_quote(input)} cat #{pages}#{rot} output #{shell_quote(output)}", output)
end

def op_encrypt
  my_puts(:blue, "\n  -- Chiffrement --")

  input = require_pdf('Fichier à chiffrer')
  return unless input

  puts "  #{COLOR[:yellow]}1#{COLOR[:nc]}. 128 bits (défaut)"
  puts "  #{COLOR[:yellow]}2#{COLOR[:nc]}. 40 bits (legacy)"
  enc = ask('Choix', default: '1') == '2' ? '40bit' : '128bit'

  print "  #{COLOR[:cyan]}>#{COLOR[:nc]} Mot de passe utilisateur (lecture) : "
  user_pw = gets&.chomp
  print "  #{COLOR[:cyan]}>#{COLOR[:nc]} Mot de passe propriétaire (modif)  : "
  owner_pw = gets&.chomp

  output = ask('Fichier de sortie', default: 'encrypted.pdf')
  output += '.pdf' unless output.end_with?('.pdf')

  cmd  = "pdftk #{shell_quote(input)} output #{shell_quote(output)} encrypt_#{enc}"
  cmd += " user_pw #{shell_quote(user_pw)}"   unless user_pw.to_s.empty?
  cmd += " owner_pw #{shell_quote(owner_pw)}" unless owner_pw.to_s.empty?

  # on ne met pas de métadonnées sur un fichier chiffré (pdftk ne peut pas
  # rouvrir le fichier sans mot de passe derrière)
  run(cmd)
end

def op_decrypt
  my_puts(:blue, "\n  -- Déchiffrement --")

  input = require_pdf('Fichier chiffré')
  return unless input

  print "  #{COLOR[:cyan]}>#{COLOR[:nc]} Mot de passe : "
  pw = gets&.chomp

  output = ask('Fichier de sortie', default: 'decrypted.pdf')
  output += '.pdf' unless output.end_with?('.pdf')

  run_with_metadata("pdftk #{shell_quote(input)} input_pw #{shell_quote(pw)} output #{shell_quote(output)}", output)
end

def op_info
  my_puts(:blue, "\n  -- Informations sur un PDF --")

  input = require_pdf('Fichier PDF')
  return unless input

  run("pdftk #{shell_quote(input)} dump_data")
end

def op_compress
  my_puts(:blue, "\n  -- Compression --")

  input = require_pdf('Fichier à compresser')
  return unless input

  output = ask('Fichier de sortie', default: 'compressed.pdf')
  output += '.pdf' unless output.end_with?('.pdf')

  run_with_metadata("pdftk #{shell_quote(input)} output #{shell_quote(output)} compress", output)
end

def op_shuffle
  my_puts(:blue, "\n  -- Assemblage interleave (recto/verso) --")
  puts "  Utile pour recombiner un scan recto et un scan verso.\n"

  input_a = require_pdf('PDF recto (pages impaires)')
  return unless input_a

  input_b = require_pdf('PDF verso (pages paires, ordre inverse)')
  return unless input_b

  output = ask('Fichier de sortie', default: 'interleaved.pdf')
  output += '.pdf' unless output.end_with?('.pdf')

  run_with_metadata(
    "pdftk A=#{shell_quote(input_a)} B=#{shell_quote(input_b)} shuffle A Bend-1 output #{shell_quote(output)}",
    output
  )
end

#  Menu 

OPERATIONS = {
  '1' => { label: 'Fusionner des PDFs',             method: :op_merge    },
  '2' => { label: 'Extraire des pages',             method: :op_extract  },
  '3' => { label: 'Diviser en pages individuelles', method: :op_burst    },
  '4' => { label: 'Faire pivoter des pages',        method: :op_rotate   },
  '5' => { label: 'Chiffrer un PDF',                method: :op_encrypt  },
  '6' => { label: 'Déchiffrer un PDF',              method: :op_decrypt  },
  '7' => { label: 'Informations sur un PDF',        method: :op_info     },
  '8' => { label: 'Compresser un PDF',              method: :op_compress },
  '9' => { label: 'Assembler (interleave) 2 PDFs',  method: :op_shuffle  },
  'q' => { label: 'Quitter',                        method: nil          }
}.freeze

def show_menu
  puts
  puts "#{COLOR[:cyan]}  +==============================+"
  puts "  |       PDF Helper -- pdftk    |"
  puts "  +==============================+#{COLOR[:nc]}"
  puts
  OPERATIONS.each do |key, op|
    next if key == 'q'
    puts "  #{COLOR[:yellow]}#{key}#{COLOR[:nc]}. #{op[:label]}"
  end
  puts "  #{COLOR[:yellow]}q#{COLOR[:nc]}. Quitter"
  puts
end

#  Point d'entrée 

check_pdftk

loop do
  show_menu
  Readline.completion_proc = proc { [] }
  choice = Readline.readline("  #{COLOR[:nc]}Choix : ", false)&.strip&.downcase

  if choice == 'q' || choice.nil?
    puts "\n  À plus tard."
    break
  end

  op = OPERATIONS[choice]
  if op.nil?
    my_puts(:red, '  Choix invalide.')
    next
  end

  send(op[:method])

  puts
  unless confirm('Effectuer une autre opération ?')
    puts "\n  À plus tard."
    break
  end
end