import 'dart:math';

class QuestionBankLocal {
  static final Random _random = Random();

  static final Map<String, List<Map<String, dynamic>>> questions = {
    'physics': _physicsQuestions(),
    'chemistry': _chemistryQuestions(),
    'maths': _mathsQuestions(),
    'biology': _biologyQuestions(),
  };

  static List<Map<String, dynamic>> _physicsQuestions() {
    return [
      {
        'q': 'A body of mass 2 kg is thrown vertically upward with a velocity of 20 m/s. What is the maximum height reached? (g = 10 m/s²)',
        'options': ['20 m', '10 m', '40 m', '30 m'],
        'correct': 0,
        'chapter': 'Motion',
        'difficulty': 1,
      },
      {
        'q': 'The SI unit of force is:',
        'options': ['Joule', 'Newton', 'Watt', 'Pascal'],
        'correct': 1,
        'chapter': 'Force and Laws of Motion',
        'difficulty': 1,
      },
      {
        'q': 'A train moving at 72 km/h is brought to rest in 20 seconds. Its deceleration is:',
        'options': ['1 m/s²', '2 m/s²', '3.6 m/s²', '4 m/s²'],
        'correct': 0,
        'chapter': 'Motion',
        'difficulty': 2,
      },
      {
        'q': 'The work done in moving a 10 N body through 5 m against gravity is:',
        'options': ['50 J', '5 J', '2 J', '100 J'],
        'correct': 0,
        'chapter': 'Work Energy and Power',
        'difficulty': 1,
      },
      {
        'q': 'Ohm\'s law states that V = IR. If voltage is doubled and resistance is halved, current becomes:',
        'options': ['Same', 'Doubled', 'Quadrupled', 'Halved'],
        'correct': 2,
        'chapter': 'Current Electricity',
        'difficulty': 2,
      },
      {
        'q': 'A convex lens of focal length 10 cm forms a real image at 20 cm. The object distance is:',
        'options': ['20 cm', '10 cm', '6.67 cm', '15 cm'],
        'correct': 0,
        'chapter': 'Light - Reflection and Refraction',
        'difficulty': 2,
      },
      {
        'q': 'The phenomenon of light bending around obstacles is called:',
        'options': ['Reflection', 'Refraction', 'Diffraction', 'Dispersion'],
        'correct': 2,
        'chapter': 'Wave Optics',
        'difficulty': 2,
      },
      {
        'q': 'Which planet in our solar system has the highest density?',
        'options': ['Jupiter', 'Saturn', 'Earth', 'Mars'],
        'correct': 2,
        'chapter': 'Gravitation',
        'difficulty': 2,
      },
      {
        'q': 'The power of a lens is -2.5 D. Its focal length is:',
        'options': ['40 cm', '-40 cm', '25 cm', '-25 cm'],
        'correct': 1,
        'chapter': 'Light - Reflection and Refraction',
        'difficulty': 1,
      },
      {
        'q': 'An object is placed at the center of curvature of a concave mirror. The image is:',
        'options': ['At focus', 'At infinity', 'At center of curvature', 'Behind the mirror'],
        'correct': 2,
        'chapter': 'Light - Reflection and Refraction',
        'difficulty': 2,
      },
      {
        'q': 'The acceleration due to gravity on the surface of the Moon is about 1/6th of that on Earth. If a body weighs 60 N on Earth, its weight on the Moon is:',
        'options': ['10 N', '60 N', '360 N', '0 N'],
        'correct': 0,
        'chapter': 'Gravitation',
        'difficulty': 1,
      },
      {
        'q': 'A current-carrying conductor placed in a magnetic field experiences a force. This is the principle of:',
        'options': ['Generator', 'Transformer', 'Electric motor', 'Galvanometer'],
        'correct': 2,
        'chapter': 'Magnetic Effects of Electric Current',
        'difficulty': 2,
      },
      {
        'q': 'The kinetic energy of a body of mass 4 kg moving with velocity 3 m/s is:',
        'options': ['12 J', '24 J', '18 J', '36 J'],
        'correct': 2,
        'chapter': 'Work Energy and Power',
        'difficulty': 1,
      },
      {
        'q': 'The phenomenon responsible for the twinkling of stars is:',
        'options': ['Reflection', 'Refraction', 'Interference', 'Diffraction'],
        'correct': 1,
        'chapter': 'Atmospheric Refraction',
        'difficulty': 2,
      },
      {
        'q': 'A body of weight W is placed on an inclined plane of angle 30°. The component of weight parallel to the plane is:',
        'options': ['W/2', 'W√3/2', 'W', 'W√2'],
        'correct': 0,
        'chapter': 'Force and Laws of Motion',
        'difficulty': 2,
      },
    ];
  }

  static List<Map<String, dynamic>> _chemistryQuestions() {
    return [
      {
        'q': 'The chemical formula of baking soda is:',
        'options': ['NaOH', 'NaHCO₃', 'Na₂CO₃', 'NaCl'],
        'correct': 1,
        'chapter': 'Acids Bases and Salts',
        'difficulty': 1,
      },
      {
        'q': 'Which gas is evolved when dilute HCl reacts with zinc?',
        'options': ['Oxygen', 'Nitrogen', 'Hydrogen', 'Carbon dioxide'],
        'correct': 2,
        'chapter': 'Acids Bases and Salts',
        'difficulty': 1,
      },
      {
        'q': 'The pH of pure water at 25°C is:',
        'options': ['0', '7', '14', '1'],
        'correct': 1,
        'chapter': 'Acids Bases and Salts',
        'difficulty': 1,
      },
      {
        'q': 'Which of the following is a covalent compound?',
        'options': ['NaCl', 'KBr', 'CCl₄', 'CaO'],
        'correct': 2,
        'chapter': 'Chemical Bonding',
        'difficulty': 2,
      },
      {
        'q': 'The atomic number of an element represents the number of:',
        'options': ['Neutrons', 'Protons', 'Electrons in outermost shell', 'Mass number'],
        'correct': 1,
        'chapter': 'Structure of the Atom',
        'difficulty': 1,
      },
      {
        'q': 'Which metal is used in the manufacture of fertilizers like urea?',
        'options': ['Sodium', 'Potassium', 'Iron', 'Aluminium'],
        'correct': 1,
        'chapter': 'Metals and Non-metals',
        'difficulty': 2,
      },
      {
        'q': 'The IUPAC name of CH₃COOH is:',
        'options': ['Methanoic acid', 'Ethanoic acid', 'Propanoic acid', 'Ethanol'],
        'correct': 1,
        'chapter': 'Carbon and its Compounds',
        'difficulty': 1,
      },
      {
        'q': 'Which of the following is an endothermic reaction?',
        'options': ['Combustion of methane', 'Dissolution of NaOH in water', 'Decomposition of CaCO₃', 'Neutralization of HCl with NaOH'],
        'correct': 2,
        'chapter': 'Chemical Reactions and Equations',
        'difficulty': 2,
      },
      {
        'q': 'The functional group present in ethanol is:',
        'options': ['Aldehyde', 'Ketone', 'Alcohol', 'Carboxylic acid'],
        'correct': 2,
        'chapter': 'Carbon and its Compounds',
        'difficulty': 1,
      },
      {
        'q': 'Which of the following metals is the best conductor of electricity?',
        'options': ['Iron', 'Copper', 'Silver', 'Aluminium'],
        'correct': 2,
        'chapter': 'Metals and Non-metals',
        'difficulty': 1,
      },
      {
        'q': 'The gas used in the Haber process for manufacturing ammonia is:',
        'options': ['Oxygen and Hydrogen', 'Nitrogen and Hydrogen', 'Nitrogen and Oxygen', 'Carbon dioxide and Hydrogen'],
        'correct': 1,
        'chapter': 'Chemical Reactions and Equations',
        'difficulty': 2,
      },
      {
        'q': 'Rusting of iron is an example of:',
        'options': ['Reduction', 'Oxidation', 'Combination', 'Displacement'],
        'correct': 1,
        'chapter': 'Chemical Reactions and Equations',
        'difficulty': 1,
      },
      {
        'q': 'Which of the following is an isomer of butane?',
        'options': ['Propane', 'Isobutane', 'Pentane', 'Ethane'],
        'correct': 1,
        'chapter': 'Carbon and its Compounds',
        'difficulty': 2,
      },
      {
        'q': 'The number of electrons in the outermost shell of a noble gas is:',
        'options': ['2', '4', '6', '8'],
        'correct': 3,
        'chapter': 'Structure of the Atom',
        'difficulty': 1,
      },
      {
        'q': 'Which salt is used in making bread and biscuits?',
        'options': ['Sodium chloride', 'Sodium hydrogen carbonate', 'Sodium carbonate', 'Calcium sulfate'],
        'correct': 1,
        'chapter': 'Acids Bases and Salts',
        'difficulty': 1,
      },
    ];
  }

  static List<Map<String, dynamic>> _mathsQuestions() {
    return [
      {
        'q': 'If sin θ = 3/5, find cos θ:',
        'options': ['3/5', '4/5', '5/4', '5/3'],
        'correct': 1,
        'chapter': 'Trigonometry',
        'difficulty': 1,
      },
      {
        'q': 'The value of log₁₀ 100 is:',
        'options': ['1', '2', '10', '100'],
        'correct': 1,
        'chapter': 'Logarithms',
        'difficulty': 1,
      },
      {
        'q': 'The quadratic equation x² - 5x + 6 = 0 has roots:',
        'options': ['1, 6', '2, 3', '-2, -3', '-1, -6'],
        'correct': 1,
        'chapter': 'Quadratic Equations',
        'difficulty': 1,
      },
      {
        'q': 'The sum of the first 10 terms of the AP: 2, 5, 8, ... is:',
        'options': ['145', '155', '135', '165'],
        'correct': 0,
        'chapter': 'Arithmetic Progressions',
        'difficulty': 2,
      },
      {
        'q': 'If A = {1, 2, 3} and B = {2, 3, 4}, then A ∪ B is:',
        'options': ['{1, 2, 3}', '{2, 3}', '{1, 2, 3, 4}', '{1, 4}'],
        'correct': 2,
        'chapter': 'Sets',
        'difficulty': 1,
      },
      {
        'q': 'The derivative of x³ with respect to x is:',
        'options': ['x²', '3x', '3x²', 'x³'],
        'correct': 2,
        'chapter': 'Calculus',
        'difficulty': 1,
      },
      {
        'q': 'The probability of getting a head when a fair coin is tossed once is:',
        'options': ['0', '1/4', '1/2', '1'],
        'correct': 2,
        'chapter': 'Probability',
        'difficulty': 1,
      },
      {
        'q': 'The area of a circle with radius 7 cm is:',
        'options': ['154 cm²', '44 cm²', '154/7 cm²', '22 cm²'],
        'correct': 0,
        'chapter': 'Mensuration',
        'difficulty': 1,
      },
      {
        'q': 'If tan θ = 1, then θ is:',
        'options': ['0°', '30°', '45°', '60°'],
        'correct': 2,
        'chapter': 'Trigonometry',
        'difficulty': 1,
      },
      {
        'q': 'The common difference of the AP: 7, 10, 13, 16, ... is:',
        'options': ['3', '7', '10', '4'],
        'correct': 0,
        'chapter': 'Arithmetic Progressions',
        'difficulty': 1,
      },
      {
        'q': 'The HCF of 12 and 18 is:',
        'options': ['6', '12', '18', '36'],
        'correct': 0,
        'chapter': 'Number Systems',
        'difficulty': 1,
      },
      {
        'q': 'The value of sin²60° + cos²60° is:',
        'options': ['0', '1', '1/2', '√3/2'],
        'correct': 1,
        'chapter': 'Trigonometry',
        'difficulty': 1,
      },
      {
        'q': 'If f(x) = 2x + 3, then f(5) is:',
        'options': ['10', '13', '8', '15'],
        'correct': 1,
        'chapter': 'Functions',
        'difficulty': 1,
      },
      {
        'q': 'The roots of x² - 4 = 0 are:',
        'options': ['±2', '±4', '2, -4', '-2, 4'],
        'correct': 0,
        'chapter': 'Quadratic Equations',
        'difficulty': 1,
      },
      {
        'q': 'The standard deviation of the data set {2, 4, 4, 4, 5, 5, 7, 9} is:',
        'options': ['2', '4', '1.5', '2.5'],
        'correct': 0,
        'chapter': 'Statistics',
        'difficulty': 2,
      },
    ];
  }

  static List<Map<String, dynamic>> _biologyQuestions() {
    return [
      {
        'q': 'The basic unit of life is:',
        'options': ['Tissue', 'Organ', 'Cell', 'Organism'],
        'correct': 2,
        'chapter': 'Cell Biology',
        'difficulty': 1,
      },
      {
        'q': 'Which organelle is known as the powerhouse of the cell?',
        'options': ['Nucleus', 'Ribosome', 'Mitochondria', 'Golgi body'],
        'correct': 2,
        'chapter': 'Cell Biology',
        'difficulty': 1,
      },
      {
        'q': 'Photosynthesis occurs in:',
        'options': ['Mitochondria', 'Chloroplast', 'Ribosome', 'Nucleus'],
        'correct': 1,
        'chapter': 'Life Processes',
        'difficulty': 1,
      },
      {
        'q': 'The process of conversion of food into energy in cells is:',
        'options': ['Photosynthesis', 'Respiration', 'Transpiration', 'Digestion'],
        'correct': 1,
        'chapter': 'Life Processes',
        'difficulty': 1,
      },
      {
        'q': 'Which blood group is known as the universal donor?',
        'options': ['A+', 'B+', 'AB+', 'O-'],
        'correct': 3,
        'chapter': 'Control and Coordination',
        'difficulty': 2,
      },
      {
        'q': 'The largest gland in the human body is:',
        'options': ['Pancreas', 'Thyroid', 'Liver', 'Kidney'],
        'correct': 2,
        'chapter': 'Life Processes',
        'difficulty': 1,
      },
      {
        'q': 'DNA stands for:',
        'options': ['Deoxyribonucleic Acid', 'Dinitrogen Acid', 'Deoxyribose Acid', 'Dioxy Nucleic Acid'],
        'correct': 0,
        'chapter': 'Heredity and Evolution',
        'difficulty': 1,
      },
      {
        'q': 'The pigment responsible for the green colour of leaves is:',
        'options': ['Carotene', 'Chlorophyll', 'Xanthophyll', 'Anthocyanin'],
        'correct': 1,
        'chapter': 'Life Processes',
        'difficulty': 1,
      },
      {
        'q': 'Which of the following is a vestigial organ in humans?',
        'options': ['Heart', 'Appendix', 'Liver', 'Kidney'],
        'correct': 1,
        'chapter': 'Heredity and Evolution',
        'difficulty': 2,
      },
      {
        'q': 'The functional unit of the kidney is:',
        'options': ['Neuron', 'Nephron', 'Alveoli', 'Villus'],
        'correct': 1,
        'chapter': 'Life Processes',
        'difficulty': 1,
      },
      {
        'q': 'Bending of a plant towards light is called:',
        'options': ['Geotropism', 'Phototropism', 'Hydrotropism', 'Chemotropism'],
        'correct': 1,
        'chapter': 'Control and Coordination',
        'difficulty': 2,
      },
      {
        'q': 'The sex chromosomes in human males are:',
        'options': ['XX', 'XY', 'YY', 'XO'],
        'correct': 1,
        'chapter': 'Heredity and Evolution',
        'difficulty': 1,
      },
      {
        'q': 'Which disease is caused by the deficiency of Vitamin C?',
        'options': ['Rickets', 'Scurvy', 'Beriberi', 'Night blindness'],
        'correct': 1,
        'chapter': 'Life Processes',
        'difficulty': 2,
      },
      {
        'q': 'The process of formation of gametes is called:',
        'options': ['Fertilization', 'Meiosis', 'Mitosis', 'Binary fission'],
        'correct': 1,
        'chapter': 'Reproduction',
        'difficulty': 2,
      },
      {
        'q': 'Which part of the plant is responsible for absorbing water from the soil?',
        'options': ['Stem', 'Leaves', 'Root hairs', 'Flowers'],
        'correct': 2,
        'chapter': 'Life Processes',
        'difficulty': 1,
      },
    ];
  }

  static List<Map<String, dynamic>> getQuestions(
    String subject, {
    String? chapter,
    int count = 10,
    int difficulty = 2,
  }) {
    final allQuestions = questions[subject] ?? [];
    var filtered = allQuestions.where((q) {
      if (chapter != null && q['chapter'] != chapter) return false;
      if (q['difficulty'] > difficulty) return false;
      return true;
    }).toList();

    filtered.shuffle(_random);
    if (filtered.length > count) {
      filtered = filtered.sublist(0, count);
    }
    return filtered;
  }

  static Map<String, dynamic> generateMathProblem(int type, int difficulty) {
    final rng = Random();

    switch (type) {
      case 0: // Arithmetic
        {
          final a = rng.nextInt(10 * difficulty) + 1;
          final b = rng.nextInt(10 * difficulty) + 1;
          final ops = ['+', '-', '×'];
          final op = ops[rng.nextInt(ops.length)];
          int answer;
          switch (op) {
            case '+':
              answer = a + b;
              break;
            case '-':
              answer = a - b;
              break;
            default:
              answer = a * b;
          }
          return {
            'q': 'What is $a $op $b?',
            'options': [answer.toString(), (answer + 1).toString(), (answer - 1).toString(), (answer + 2).toString()],
            'correct': 0,
            'chapter': 'Arithmetic',
            'difficulty': difficulty,
          };
        }
      case 1: // Percentage
        {
          final whole = (rng.nextInt(9) + 1) * 10;
          final percent = (rng.nextInt(4) + 1) * 25;
          final answer = (whole * percent) ~/ 100;
          return {
            'q': 'What is $percent% of $whole?',
            'options': [answer.toString(), (answer + 1).toString(), (answer - 1).toString(), (answer + 2).toString()],
            'correct': 0,
            'chapter': 'Percentage',
            'difficulty': difficulty,
          };
        }
      case 2: // Ratio
        {
          final a = rng.nextInt(5) + 1;
          final b = rng.nextInt(5) + 1;
          return {
            'q': 'Simplify the ratio ${a * 10}:${b * 10}',
            'options': ['$a:$b', '${b}:${a}', '${a + 1}:${b + 1}', '${a}:${b + 1}'],
            'correct': 0,
            'chapter': 'Ratio and Proportion',
            'difficulty': difficulty,
          };
        }
      case 3: // Simple Interest
        {
          final principal = (rng.nextInt(5) + 1) * 1000;
          final rate = (rng.nextInt(4) + 1) * 2;
          final time = rng.nextInt(4) + 1;
          final si = (principal * rate * time) ~/ 100;
          return {
            'q': 'Find the simple interest on Rs.$principal at $rate% per annum for $time years.',
            'options': ['Rs.$si', 'Rs.${si + 50}', 'Rs.${si - 50}', 'Rs.${si + 100}'],
            'correct': 0,
            'chapter': 'Simple and Compound Interest',
            'difficulty': difficulty,
          };
        }
      default:
        {
          final a = rng.nextInt(20) + 1;
          final b = rng.nextInt(20) + 1;
          return {
            'q': 'What is $a + $b?',
            'options': [(a + b).toString(), (a + b + 1).toString(), (a + b - 1).toString(), (a + b + 2).toString()],
            'correct': 0,
            'chapter': 'Arithmetic',
            'difficulty': difficulty,
          };
        }
    }
  }
}
