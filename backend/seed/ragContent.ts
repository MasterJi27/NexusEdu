/**
 * Seed study material for the RAG corpus (shared chunks, userId = null).
 *
 * NCERT-aligned, exam-focused content for the most-asked chapters. Every item
 * is written to be directly usable by a Class 9-12 CBSE/ICSE/state student:
 * concepts first, then key points, formulas and common exam questions.
 *
 * Run with: npm run seed:rag
 */

export interface RagSeedItem {
  gradeLevel: string;
  subject: string;
  title: string;
  content: string;
}

export const RAG_SEED: RagSeedItem[] = [
  // ---------------------------------------------------------------------
  // Class 10 Science
  // ---------------------------------------------------------------------
  {
    gradeLevel: 'Class 10',
    subject: 'Science',
    title: 'Life Processes: Nutrition and Respiration',
    content: `Life processes are the basic activities that keep living organisms alive: nutrition, respiration, transportation and excretion.

Nutrition: Nutrition is the process of taking in food and using it to obtain energy. In plants, photosynthesis is the process where chlorophyll-containing cells use sunlight energy to convert carbon dioxide and water into glucose and oxygen. The equation is 6CO2 + 6H2O + sunlight -> C6H12O6 + 6O2. Photosynthesis happens in chloroplasts, which contain the green pigment chlorophyll. It has two main phases: the light reaction (which needs sunlight and produces ATP) and the dark reaction or Calvin cycle (which uses ATP to fix CO2 into glucose). Plants mainly take in CO2 through stomata, tiny pores on leaves.

In animals, nutrition is heterotrophic: they cannot make their own food. Humans follow the steps ingestion, digestion, absorption, assimilation and egestion. Digestion begins in the mouth where saliva breaks down starch with the enzyme salivary amylase. The stomach secretes hydrochloric acid (HCl), which kills bacteria and creates an acidic medium for pepsin to digest proteins. The small intestine is the main site of digestion and absorption: bile from the liver emulsifies fats, pancreatic juice digests carbohydrates, proteins and fats, and the finger-like villi absorb digested food into the blood.

Respiration: Respiration releases energy from glucose. Aerobic respiration uses oxygen: C6H12O6 + 6O2 -> 6CO2 + 6H2O + 38 ATP (energy). Anaerobic respiration happens without oxygen, producing ethanol and CO2 in yeast or lactic acid in muscles, releasing only 2 ATP. In humans, breathing exchanges gases in alveoli, tiny air sacs in the lungs with a huge surface area and thin walls for efficient exchange. Oxygen is carried by haemoglobin in red blood cells.

Common exam questions: (1) Why is the small intestine the main site of digestion? (2) Write the difference between aerobic and anaerobic respiration. (3) Where does photosynthesis occur and what is its equation? (4) What is the role of villi?`,
  },
  {
    gradeLevel: 'Class 10',
    subject: 'Science',
    title: 'Life Processes: Transportation and Excretion',
    content: `Transportation in humans: The blood transports oxygen, nutrients, hormones and waste. It has plasma (the liquid part), red blood cells (carry oxygen via haemoglobin), white blood cells (fight infection) and platelets (help clotting). Blood is pumped by the heart, a four-chambered muscular organ: the right atrium receives deoxygenated blood from the body and the right ventricle sends it to the lungs; the left atrium receives oxygenated blood from the lungs and the left ventricle pumps it to the whole body. Double circulation means blood passes through the heart twice in one full circuit.

Blood vessels: Arteries carry blood away from the heart (oxygenated, except pulmonary artery), veins carry blood back to the heart (deoxygenated, except pulmonary vein), and capillaries are thin-walled vessels where exchange of substances happens. Pulse is the pressure wave of blood in arteries, measured as blood pressure (systolic/diastolic).

Transportation in plants: Plants do not have a heart. Xylem transports water and minerals from roots to leaves in one direction. Water rises because of transpiration pull: water evaporates from leaves through stomata, creating suction that pulls the water column up. Phloem transports prepared food (sugars) from leaves to all parts of the plant, in both directions, by a process called translocation which needs energy.

Excretion in humans: Excretion removes metabolic waste. The kidneys filter blood to form urine. Each kidney has millions of nephrons, the functional units. Filtration happens in the glomerulus, useful substances are reabsorbed in the tubule, and urine passes through the ureters to the urinary bladder and out through the urethra. Other excretory organs: lungs excrete CO2, skin excretes sweat (water, salt, urea), liver breaks down haemoglobin into bile pigments (bilirubin) which give stool its colour.

Excretion in plants: Plants excrete oxygen (from photosynthesis), store waste in leaves which fall off, and deposit some waste as resins and gums in old xylem.

Common exam questions: (1) Why is double circulation needed in humans? (2) What is the role of xylem and phloem? (3) Draw the path of blood through the heart. (4) What is a nephron and where does filtration occur?`,
  },
  {
    gradeLevel: 'Class 10',
    subject: 'Science',
    title: 'Light: Reflection and Refraction',
    content: `Light travels in straight lines. Reflection is the bouncing back of light from a surface. The laws of reflection: (1) the incident ray, reflected ray and the normal all lie in the same plane, and (2) the angle of incidence equals the angle of reflection. Plane mirrors form virtual, erect and laterally inverted images the same size as the object.

Spherical mirrors: Concave mirrors curve inward and form real (or virtual) images; they are used in torches, headlights and shaving mirrors. Convex mirrors curve outward and always form virtual, erect, diminished images with a wide field of view; they are used as rear-view mirrors in vehicles. Mirror formula: 1/v + 1/u = 1/f, where u is object distance, v is image distance and f is focal length. Sign convention: distances measured from the pole, positive in the direction of incident light, negative opposite. Magnification m = -v/u = height of image / height of object.

Refraction: When light changes speed and bends while passing from one medium to another, it is refraction. Snell's law: n1 sin i = n2 sin r. When light goes from a rarer to a denser medium (air to glass), it bends towards the normal. Refractive index n = speed of light in vacuum / speed of light in medium. The lens formula is 1/v - 1/u = 1/f. Power of a lens P = 1/f (in metres), measured in dioptres.

Convex lenses converge light and form real, inverted images (used in magnifying glasses, cameras, eyes). Concave lenses diverge light and always form virtual, erect, diminished images (used to correct myopia). A convex lens of focal length f has power P = +1/f dioptres; a concave lens has negative power.

Common exam questions: (1) State the laws of reflection. (2) Why is a convex mirror used as a rear-view mirror? (3) An object is placed 20 cm from a concave mirror of focal length 10 cm. Find the image position and nature. (4) Difference between real and virtual image.`,
  },
  {
    gradeLevel: 'Class 10',
    subject: 'Science',
    title: 'Electricity: Current, Ohm\u2019s Law and Circuits',
    content: `Electric current is the flow of electric charge, measured in amperes (A). I = Q/t, where Q is charge in coulombs and t is time in seconds. A battery provides potential difference (voltage, V), measured in volts, which pushes charge around the circuit.

Ohm's law: At constant temperature, the current through a conductor is directly proportional to the potential difference across it: V = IR, where R is resistance in ohms. Resistance depends on the material (resistivity rho), length L and area of cross-section A: R = rho * L / A. Conductors have low resistivity (copper, silver), insulators have high resistivity (rubber, plastic). Good conductors have low resistivity.

Resistors in series: R_total = R1 + R2 + R3. Same current flows through each; total voltage divides. Resistors in parallel: 1/R_total = 1/R1 + 1/R2 + 1/R3. Same voltage across each; current divides. Parallel circuits are used in homes because each appliance gets the full supply voltage and one appliance failing does not affect the others.

Heating effect of electric current: When current flows through a resistor, energy is converted to heat: H = I^2 R t (Joule's law). Electric power P = VI = I^2 R = V^2/R, measured in watts. Commercial unit of energy is the kilowatt-hour (kWh): 1 kWh = 3.6 million joules. This is what electricity bills measure.

Electric fuse: A fuse is a thin wire of low melting point (tin-lead alloy) connected in series with the circuit. If current exceeds the safe value, the fuse wire melts and breaks the circuit, protecting appliances. Earthing connects the metal body of appliances to the ground so leakage current flows to earth instead of through a person. In domestic wiring, red is live, black is neutral, green is earth.

Common exam questions: (1) State Ohm's law and its conditions. (2) Derive the expression for power in terms of resistance. (3) Two resistors of 4 ohm and 6 ohm are in parallel; find equivalent resistance. (4) Why does a fuse melt when current is high?`,
  },

  // ---------------------------------------------------------------------
  // Class 10 Mathematics
  // ---------------------------------------------------------------------
  {
    gradeLevel: 'Class 10',
    subject: 'Mathematics',
    title: 'Quadratic Equations',
    content: `A quadratic equation is an equation of the form ax^2 + bx + c = 0, where a is not equal to zero. Examples: x^2 - 5x + 6 = 0, 2x^2 + 3x - 1 = 0.

Solving methods: (1) Factorisation: split the middle term. For x^2 - 5x + 6 = 0, find two numbers whose product is 6 and sum is -5: they are -2 and -3, so (x - 2)(x - 3) = 0, giving x = 2 or x = 3. (2) Completing the square. (3) Quadratic formula: x = [-b +- sqrt(b^2 - 4ac)] / 2a.

Discriminant: D = b^2 - 4ac decides the nature of roots. If D > 0: two distinct real roots. If D = 0: two equal real roots (one repeated root). If D < 0: no real roots (complex roots). Example: x^2 - 6x + 9 = 0 has D = 36 - 36 = 0, so one repeated root x = 3.

Sum and product of roots: For ax^2 + bx + c = 0, sum of roots = -b/a, product of roots = c/a.

Word problems: (1) Product of two consecutive integers is 306: x(x+1) = 306, so x^2 + x - 306 = 0, x = 17 or -18, answer 17 and 18. (2) Area problems: a rectangular garden whose length is 4 m more than its width and area is 60 sq m: x(x+4) = 60, x^2 + 4x - 60 = 0, x = 6, so width 6 m, length 10 m.

Common exam questions: (1) Find the roots of 2x^2 - 7x + 3 = 0. (2) For what value of k does x^2 + kx + 9 = 0 have equal roots? (k = +-6, since D = k^2 - 36 = 0). (3) The sum of the squares of two consecutive odd integers is 74. Find them.`,
  },
  {
    gradeLevel: 'Class 10',
    subject: 'Mathematics',
    title: 'Triangles: Similarity',
    content: `Two triangles are similar if their corresponding angles are equal and corresponding sides are in the same ratio. Notation: triangle ABC ~ triangle DEF. Similarity is different from congruence: congruent triangles are exactly equal (SSS, SAS, ASA, RHS), similar triangles have the same shape but possibly different size.

Basic Proportionality Theorem (Thales' theorem): If a line is drawn parallel to one side of a triangle intersecting the other two sides, it divides them in the same ratio. If DE is parallel to BC in triangle ABC, then AD/DB = AE/EC. The converse is also true: if a line divides two sides of a triangle in the same ratio, it is parallel to the third side.

Criteria for similarity: (1) AA (Angle-Angle): two angles equal. (2) SSS: all three sides proportional. (3) SAS: two sides proportional and the included angle equal.

Important results: The ratio of areas of two similar triangles equals the square of the ratio of their corresponding sides: area(ABC)/area(DEF) = (AB/DE)^2. This is a frequently tested result. Also, in a right triangle, the altitude to the hypotenuse creates two smaller triangles similar to the original.

Common exam questions: (1) State and prove Thales' theorem. (2) If triangle ABC ~ triangle PQR and AB/PQ = 2/3, what is the ratio of their areas? (Answer: 4/9.) (3) In triangle ABC, DE || BC, AD = 3 cm, DB = 2 cm, AE = 4.5 cm. Find EC. (Answer: EC = 3 cm by BPT.)`,
  },
  {
    gradeLevel: 'Class 10',
    subject: 'Mathematics',
    title: 'Introduction to Trigonometry',
    content: `Trigonometry studies relationships between angles and sides of triangles. In a right triangle with angle theta: sin theta = opposite/hypotenuse, cos theta = adjacent/hypotenuse, tan theta = opposite/adjacent = sin/cos. Also: cosec theta = 1/sin, sec theta = 1/cos, cot theta = 1/tan.

Standard values (memorise): sin 0 = 0, sin 30 = 1/2, sin 45 = 1/sqrt2, sin 60 = sqrt3/2, sin 90 = 1. Cos is the reverse: cos 0 = 1, cos 30 = sqrt3/2, cos 45 = 1/sqrt2, cos 60 = 1/2, cos 90 = 0. Tan = sin/cos: tan 0 = 0, tan 30 = 1/sqrt3, tan 45 = 1, tan 60 = sqrt3, tan 90 is undefined.

Identities (identities hold for all angles): sin^2 theta + cos^2 theta = 1. Dividing by cos^2: tan^2 theta + 1 = sec^2 theta. Dividing by sin^2: 1 + cot^2 theta = cosec^2 theta.

Applications: Heights and distances problems use angle of elevation (looking up) and angle of depression (looking down). Example: A tower casts a shadow equal to its height; find the angle of elevation of the sun. If height = shadow length, tan theta = 1, so theta = 45 degrees.

Common exam questions: (1) Prove that sin^2 A + cos^2 A = 1 for A = 30 and verify. (2) Evaluate (sin 30 + cos 60) / (tan 45 + cot 45). (3) From the top of a 100 m building the angle of depression of a car is 30 degrees; find the distance of the car from the building. (Answer: 100 * sqrt3 m.)`,
  },

  // ---------------------------------------------------------------------
  // Class 12 Physics
  // ---------------------------------------------------------------------
  {
    gradeLevel: 'Class 12',
    subject: 'Physics',
    title: 'Electrostatics: Coulomb\u2019s Law and Electric Field',
    content: `Electrostatics is the study of charges at rest. Like charges repel, unlike charges attract. Coulomb's law: the force between two point charges q1 and q2 separated by distance r is F = k q1 q2 / r^2, where k = 1/(4 pi epsilon0) = 9 x 10^9 N m^2/C^2, and epsilon0 is the permittivity of free space. Force is a vector along the line joining the charges.

Electric field: The electric field at a point is the force per unit positive charge: E = F/q, measured in N/C or V/m. For a point charge, E = k Q / r^2, radially outward for positive charge, inward for negative. Field lines start on positive charges and end on negative charges; they never cross.

Electric potential: Potential at a point is the work done per unit charge in bringing a charge from infinity to that point: V = k Q / r, in volts. Potential is a scalar. Work done to move charge q through potential difference V is W = qV. Potential difference between two points is V_AB = V_A - V_B = W/q.

Capacitance: A capacitor stores charge. C = Q/V, in farads. Parallel plate capacitor: C = epsilon0 A / d, where A is plate area and d is separation. Capacitors in series: 1/C = 1/C1 + 1/C2. In parallel: C = C1 + C2. Energy stored in a capacitor: U = (1/2) C V^2.

Common exam questions: (1) State Coulomb's law and define permittivity. (2) Derive the expression for the electric field of a point charge. (3) Two charges 3 microC and -3 microC are 10 cm apart; find the force between them. (4) Capacitors of 2 and 3 microF in parallel; find total capacitance and energy at 10 V.`,
  },
  {
    gradeLevel: 'Class 12',
    subject: 'Physics',
    title: 'Current Electricity',
    content: `Current electricity is the study of moving charges. Electric current I = dQ/dt, measured in amperes. Conventional current flows from positive to negative. Drift velocity vd is the average velocity of electrons under an applied field; current I = n A e vd, where n is electron density, A is cross-sectional area, e is electron charge.

Ohm's law: V = IR. Resistance R = rho L / A, where rho is resistivity. Resistivity depends on temperature: rho = rho0 [1 + alpha(T - T0)]; metals have positive temperature coefficient (resistance increases when hot), semiconductors have negative coefficient. Conductance G = 1/R, in siemens.

Combination of resistors: Series: R = R1 + R2 + R3, same current. Parallel: 1/R = 1/R1 + 1/R2 + 1/R3, same voltage. The total resistance of a parallel combination is always less than the smallest individual resistance.

Kirchhoff's laws: (1) Junction rule: the sum of currents entering a junction equals the sum leaving it (charge conservation). (2) Loop rule: the algebraic sum of potential differences around any closed loop is zero (energy conservation). These solve complex circuits.

Internal resistance: A battery has internal resistance r, so terminal voltage V = E - I r, where E is emf. Cells in series add emfs; cells in parallel last longer for high-current devices. Maximum power transfer happens when load resistance equals internal resistance.

Common exam questions: (1) State Kirchhoff's laws. (2) Why does the total resistance of a parallel circuit decrease? (3) A battery of emf 12 V and internal resistance 1 ohm drives a 5 ohm resistor; find current and terminal voltage. (4) Wheatstone bridge balance condition: P/Q = R/S.`,
  },
  {
    gradeLevel: 'Class 12',
    subject: 'Physics',
    title: 'Ray Optics: Lenses and Optical Instruments',
    content: `Ray optics studies light using rays, ignoring wave nature. Refraction: light bends when changing medium. Snell's law: n1 sin i = n2 sin r. Refractive index n = c/v. Total internal reflection happens when light travels from denser to rarer medium and the angle of incidence exceeds the critical angle, where sin C = 1/n (for glass to air, C is about 42 degrees). This is the principle behind optical fibres and diamonds' sparkle.

Lens formula: 1/v - 1/u = 1/f. Magnification m = v/u. A convex lens (converging) of focal length f forms: real inverted images for objects beyond focus, and virtual erect magnified images for objects within focus (magnifying glass). A concave lens always forms virtual, erect, diminished images. Power P = 1/f in dioptres; convex positive, concave negative.

The human eye acts like a camera: the cornea and lens focus light on the retina; the ciliary muscles change lens curvature for accommodation. Defects: myopia (near-sightedness, image forms before retina) is corrected with a concave lens; hypermetropia (far-sightedness, image forms behind retina) with a convex lens; presbyopia with bifocal lenses. The power of a lens in dioptres = 1 / focal length in metres.

Compound microscope: two convex lenses, objective (short focal length, forms real image) and eyepiece (magnifies that image). Total magnification = m_objective x m_eyepiece. Astronomical telescope: objective of large focal length forms real image of distant object, eyepiece magnifies it. Magnifying power of telescope = f_o / f_e.

Common exam questions: (1) Define critical angle and state conditions for total internal reflection. (2) An object is placed 30 cm from a convex lens of focal length 10 cm; find image position, nature and magnification. (3) A person needs a concave lens of power -2 D; find focal length. (Answer: -50 cm.)`,
  },

  // ---------------------------------------------------------------------
  // Class 12 Chemistry
  // ---------------------------------------------------------------------
  {
    gradeLevel: 'Class 12',
    subject: 'Chemistry',
    title: 'Solutions: Concentration and Colligative Properties',
    content: `A solution is a homogeneous mixture of solute and solvent. Concentration units: molarity M = moles of solute / litres of solution; molality m = moles of solute / kg of solvent; mole fraction x_A = moles of A / total moles; mass percentage = (mass of solute / mass of solution) x 100. Molality is temperature-independent; molarity changes with temperature because volume changes.

Henry's law: the solubility of a gas in a liquid is proportional to the partial pressure of the gas above it: p = K_H x. Soft drinks are bottled under high CO2 pressure for this reason. Gas solubility decreases with rising temperature.

Raoult's law: the partial vapour pressure of each component is proportional to its mole fraction: p_A = x_A p_A^0. Ideal solutions obey Raoult's law at all concentrations and have zero enthalpy and volume change of mixing (e.g., benzene + toluene). Non-ideal solutions show positive deviation (ethanol + water, stronger A-B forces than pure) or negative deviation (chloroform + acetone, hydrogen bonding).

Colligative properties depend only on the number of solute particles, not their identity: (1) relative lowering of vapour pressure = x_solute, (2) elevation of boiling point delta T_b = K_b m, (3) depression of freezing point delta T_f = K_f m, (4) osmotic pressure pi = CRT, where C is molar concentration, R gas constant, T temperature. Osmosis drives water absorption in plant roots and preservation of fruits in sugar (hypertonic) solutions.

Van't Hoff factor i = actual number of particles / expected number. Electrolytes have i > 1 (NaCl gives i = 2); associated solutes have i < 1. Corrected colligative property = i x ideal value.

Common exam questions: (1) Define molality and molarity. (2) State Raoult's law. (3) Calculate the freezing point depression for a 0.5 m glucose solution (K_f water = 1.86 K kg/mol). (4) Why does adding salt lower the freezing point of water?`,
  },
  {
    gradeLevel: 'Class 12',
    subject: 'Chemistry',
    title: 'Electrochemistry: Cells and Nernst Equation',
    content: `Electrochemistry links chemical reactions and electricity. A galvanic (voltaic) cell converts chemical energy to electrical energy using a spontaneous redox reaction. Example: Daniel cell has zinc (anode, oxidation: Zn -> Zn2+ + 2e-) and copper (cathode, reduction: Cu2+ + 2e- -> Cu). Electrons flow from anode to cathode through the external circuit; a salt bridge completes the circuit and maintains charge balance.

Standard electrode potential E^0 measures a half-cell's tendency to gain electrons relative to the standard hydrogen electrode (SHE, E^0 = 0 V). Cell potential E_cell = E_cathode - E_anode. A positive cell potential means a spontaneous reaction.

Nernst equation: E = E^0 - (0.0591/n) log Q at 25 degrees C, where Q is the reaction quotient and n is the number of electrons transferred. For the Daniel cell, E = E^0 - (0.0591/2) log [Zn2+]/[Cu2+]. At equilibrium, E = 0 and Q = K (equilibrium constant): log K = n E^0 / 0.0591.

Electrolysis: passing current through a molten salt or solution causes non-spontaneous decomposition. Faraday's laws: mass deposited m = (Z I t), where Z is electrochemical equivalent, I is current, t is time. One faraday (96500 C) deposits one gram-equivalent. Applications: electrorefining of copper, electroplating of jewellery and utensils.

Batteries: primary cells (dry cell, cannot be recharged) and secondary cells (lead-acid car battery, nickel-cadmium, lithium-ion — rechargeable). Fuel cells combine H2 and O2 to produce water and electricity, used in spacecraft.

Common exam questions: (1) Write the cell reaction of the Daniel cell. (2) Calculate E of the Daniel cell using Nernst equation for [Zn2+] = 0.1 M, [Cu2+] = 1 M, E^0 = 1.1 V. (3) State Faraday's first law. (4) Why is a salt bridge needed?`,
  },
  {
    gradeLevel: 'Class 12',
    subject: 'Chemistry',
    title: 'Chemical Kinetics: Rate and Order of Reactions',
    content: `Chemical kinetics studies the speed of reactions and the factors that control it. Rate of reaction = change in concentration per unit time: rate = -d[R]/dt = +d[P]/dt. Average rate is over an interval; instantaneous rate is the slope of the concentration-time curve at a moment.

Rate law: rate = k [A]^m [B]^n, where k is the rate constant, m and n are orders with respect to A and B. Order is determined experimentally, never from the balanced equation. First order reaction: rate = k[A], units of k are s^-1. Second order: rate = k[A]^2, units L mol^-1 s^-1. Zero order: rate = k, units mol L^-1 s^-1.

First-order kinetics: integrated rate law ln([A]0/[A]) = kt, or [A] = [A]0 e^-kt. Half-life t1/2 = 0.693/k — independent of initial concentration, which is the hallmark of first-order reactions (used for radioactive decay, drug metabolism).

Arrhenius equation: k = A e^(-Ea/RT), where Ea is activation energy, A is frequency factor. log k = log A - Ea/(2.303 R T). Higher Ea means a slower reaction at the same temperature. Catalysts lower Ea by providing an alternative path, speeding the reaction without being consumed. A catalyst does not change the equilibrium position.

Common exam questions: (1) A first-order reaction has k = 2.31 x 10^-3 s^-1; find its half-life. (Answer: 300 s.) (2) The half-life of a reaction is independent of concentration; what is its order? (3) What is the effect of temperature on rate constant? (4) Define activation energy and explain catalyst action.`,
  },
];
