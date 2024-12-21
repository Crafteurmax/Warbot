/////////////////////////////////////////////////////////////////////////// //<>// //<>//
//
// The code for the green team
// ===========================
//
///////////////////////////////////////////////////////////////////////////

class GreenTeam extends Team {
  final int MY_CUSTOM_MSG = 5;
  PVector base1, base2;

  // coordinates of the 2 bases, chosen in the rectangle with corners
  // (0, 0) and (width/2, height-100)
  GreenTeam() {
    base1 = new PVector(width/2 - 300, (height - 100)/2 - 150); // first base
    base2 = new PVector(width/2 - 300, (height - 100)/2 + 150); // second base
  }  
}

interface GreenRobot {
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the green bases
//
///////////////////////////////////////////////////////////////////////////
// map of the brain:
//   5.x = nb of harvesters left to create
//   5.y = nb of rocket launchers left to create
//   5.z = nb of explorers left to create
//   
///////////////////////////////////////////////////////////////////////////
class GreenBase extends Base implements GreenRobot {
  //
  // constructor
  // ===========
  //
  GreenBase(PVector p, color c, Team t) {
    super(p, c, t);
  }

  //
  // setup
  // =====
  // > called at the creation of the base
  //
  void setup() {
    newExplorer(); // creates a new harvester
    brain[5].z = 7; // 7 more harvesters to create
  }


  
  //
  // createNewRobots
  // ==
  // > create new robots depending on what ressources we have
  //
void createNewRobots() {
  // creates new robots depending on energy and the state of brain[5]
    if ((brain[5].x > 0) && (energy >= 1000 + harvesterCost)) {
      // 1st priority = creates harvesters 
      if (newHarvester()) brain[5].x--;
    } 
    else if ((brain[5].y > 0) && (energy >= 1000 + launcherCost)) {
      // 2nd priority = creates rocket launchers 
      if (newRocketLauncher()) brain[5].y--;
    } 
    else if ((brain[5].z > 0) && (energy >= 1000 + explorerCost)) {
      // 3rd priority = creates explorers 
      if (newExplorer()) brain[5].z--;
    } 
    else if (energy > 12000) {
      // if no robot in the pipe and enough energy 
      // creates a new harvester with 50% chance, a new rocket launcher with 25% chance, a new explorer with 25% chance
      if ((int)random(2) == 0) brain[5].x++; 
      else if ((int)random(2) == 0) brain[5].y++;
      else brain[5].z++;
    }
}


  //
  // go
  // ==
  // > called at each iteration of the game
  // > defines the behavior of the agent
  //
  void go() {
    // handle received messages 
    handleMessages();
    createNewRobots();

    // creates new bullets and fafs if the stock is low and enought energy
    if ((bullets < 10) && (energy > 1000)) newBullets(50); 
    if ((bullets < 10) && (energy > 1000)) newFafs(10);

    // if ennemy rocket launcher in the area of perception
    Robot bob = (Robot)minDist(perceiveRobots(ennemy, LAUNCHER));
    if (bob != null) {
      heading = towards(bob);
      // launch a faf if no friend robot on the trajectory...
      if (perceiveRobotsInCone(friend, heading) == null) launchFaf(bob);
    }
  }

  //
  // handleMessage
  // =============
  // > handle messages received since last activation 
  //
  void handleMessages() {
    Message msg;
    // for all messages
    for (int i=0; i<messages.size(); i++) {
      msg = messages.get(i);
      if (msg.type == ASK_FOR_ENERGY) {
        // if the message is a request for energy
        if (energy > 1000 + msg.args[0]) {
          giveEnergy(msg.alice, msg.args[0]); // gives the requested amount of energy only if at least 1000 units of energy left after
        }
      } 
      else if (msg.type == ASK_FOR_BULLETS) {
        // if the message is a request for energy
        if (energy > 1000 + msg.args[0] * bulletCost) {
          giveBullets(msg.alice, msg.args[0]); // gives the requested amount of bullets only if at least 1000 units of energy left after
        }
      }
    }

    flushMessages(); // clear the message queue
  }
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the green explorers
//
///////////////////////////////////////////////////////////////////////////
// map of the brain:
//   4.x = (0 = exploration | 1 = go back to base)
//   4.y = (0 = no target | 1 = locked target)
//   0.x / 0.y = coordinates of the target
//   0.z = type of the target
///////////////////////////////////////////////////////////////////////////
class GreenExplorer extends Explorer implements GreenRobot {
  //
  // constructor
  // ===========
  //
  GreenExplorer(PVector pos, color c, ArrayList b, Team t) {
    super(pos, c, b, t);
  }

  //
  // setup
  // =====
  // > called at the creation of the agent
  //
  void setup() {
  }

  //
  // go
  // ==
  // > called at each iteration of the game
  // > defines the behavior of the agent
  //
  void go() {
    
    if ((carryingFood > 200) || (energy < 100)) brain[4].x = 1; // if food to deposit or too few energy then time to go back to base

    // depending on the state of the robot
    if (brain[4].x == 1) { 
      goBackToBase(); // go back to base...
    } 
    else {
      // or else explore randomly
      heading += random(-radians(45), radians(45)); // randomly computes the new heading
      if (freeAhead(speed, collisionAngle)) forward(speed); // if the environment is free ahead of the robot then move forward at full speed
    }

    lookForEnnemyBase(); // tries to localize ennemy bases
    driveHarvesters(); // inform harvesters about food sources
    driveRocketLaunchers(); // inform rocket launchers about targets

    flushMessages(); // clear the message queue
  }

  //
  // setTarget
  // =========
  // > locks a target
  //
  // inputs
  // ------
  // > p = the location of the target
  // > breed = the breed of the target
  //
  void setTarget(PVector p, int breed) {
    brain[0].x = p.x;
    brain[0].y = p.y;
    brain[0].z = breed;
    brain[4].y = 1;
  }

  //
  // goBackToBase
  // ============
  // > go back to the closest base, either to deposit food or to reload energy
  //
  void goBackToBase() {
    // bob is the closest base
    Base bob = (Base)minDist(myBases);
    if (bob != null) {
      // if there is one (not all of my bases have been destroyed)
      float dist = distance(bob);

      if (dist <= 2) {
        // if I am next to the base
        if (energy < 500) askForEnergy(bob, 1500 - energy); // if my energy is low, I ask for some more
        brain[4].x = 0; // switch to the exploration state
        right(180); // make a half turn
      } 
      else {
        // if still away from the base head towards the base (with some variations)and try to move forward 
        heading = towards(bob) + random(-radians(20), radians(20));
        tryToMoveForward();
      }
    }
  }

  //
  // target
  // ======
  // > checks if a target has been locked
  //
  // output
  // ------
  // true if target locket / false if not
  //
  boolean target() {
    return (brain[4].y == 1);
  }

  //
  // driveHarvesters
  // ===============
  // > tell harvesters if food is localized
  //
  void driveHarvesters() {
    // look for burgers
    Burger zorg = (Burger)oneOf(perceiveBurgers());
    if (zorg != null) {
      Harvester harvey = (Harvester)oneOf(perceiveRobots(friend, HARVESTER)); // if one is seen, look for a friend harvester
      if (harvey != null)informAboutFood(harvey, zorg.pos); // if a harvester is seen, send a message to it with the position of food
    }
  }

  //
  // driveRocketLaunchers
  // ====================
  // > tell rocket launchers about potential targets
  //
  void driveRocketLaunchers() {
    // look for an ennemy robot 
    Robot bob = (Robot)oneOf(perceiveRobots(ennemy));
    if (bob != null) {
      // if one is seen, look for a friend rocket launcher
      RocketLauncher rocky = (RocketLauncher)oneOf(perceiveRobots(friend, LAUNCHER));
      if (rocky != null) informAboutTarget(rocky, bob); // if a rocket launcher is seen, send a message with the localized ennemy robot
    }
  }

  //
  // lookForEnnemyBase
  // =================
  // > try to localize ennemy bases...
  // > ...and to communicate about this to other friend explorers
  //
  void lookForEnnemyBase() {
    // look for an ennemy base
    Base babe = (Base)oneOf(perceiveRobots(ennemy, BASE));
    if (babe != null) {
      // if one is seen, look for a friend explorer
      Explorer explo = (Explorer)oneOf(perceiveRobots(friend, EXPLORER));
      if (explo != null) informAboutTarget(explo, babe); // if one is seen, send a message with the localized ennemy baseBase basy = (Base)oneOf(perceiveRobots(friend, BASE)); // look for a friend base
      Base basy = (Base)oneOf(perceiveRobots(friend, BASE));
      if (basy != null) informAboutTarget(basy, babe); // if one is seen, send a message with the localized ennemy base
    }
  }

  //
  // tryToMoveForward
  // ================
  // > try to move forward after having checked that no obstacle is in front
  //
  void tryToMoveForward() {
    if (!freeAhead(speed)) right(random(360)); // if there is an obstacle ahead, rotate randomly
    if (freeAhead(speed)) forward(speed * 0.1); // if there is no obstacle ahead, move forward at full speed
  }
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the green harvesters
//
///////////////////////////////////////////////////////////////////////////
// map of the brain:
//   4.x = (0 = look for food | 1 = go back to base) 
//   4.y = (0 = no food found | 1 = food found)
//   0.x / 0.y = position of the localized food
///////////////////////////////////////////////////////////////////////////
class GreenHarvester extends Harvester implements GreenRobot {
  //
  // constructor
  // ===========
  //
  GreenHarvester(PVector pos, color c, ArrayList b, Team t) {
    super(pos, c, b, t);
  }

  //
  // setup
  // =====
  // > called at the creation of the agent
  //
  void setup() {
  }

  //
  // go
  // ==
  // > called at each iteration of the game
  // > defines the behavior of the agent
  //
  void go() {
    
    handleMessages(); // handle messages received
    Burger b = (Burger)minDist(perceiveBurgers()); // check for the closest burger
    
    if ((b != null) && (distance(b) <= 2)) takeFood(b); // if one is found next to the robot, collect it
    if ((carryingFood > 200) || (energy < 100)) brain[4].x = 1; // if food to deposit or too few energy, then it's time to go back to the base

    // if in "go back" state
    if (brain[4].x == 1) {
      goBackToBase(); // go back to the base

      // if the robot enough has energy and food
      if ((energy > 100) && (carryingFood > 100)) {
        Base bob = (Base)minDist(myBases); // check for closest base
        if (bob != null) {
          // if there is one and the harvester is in the sphere of perception of the base
          if (distance(bob) < basePerception) plantSeed(); // plant one burger as a seed to produce new ones
        }
      }
    } 
    else goAndEat(); // if not in the "go back" state, explore and collect food
  }

  //
  // goBackToBase
  // ============
  // > go back to the closest friend base
  //
  void goBackToBase() {
    // look for the closest base
    Base bob = (Base)minDist(myBases);
    if (bob != null) {
      // if there is one
      float dist = distance(bob);
      if ((dist > basePerception) && (dist < basePerception + 1)) dropWall(); // if at the limit of perception of the base, drops a wall (if it carries some)
 
      if (dist <= 2) {
        // if next to the base 
        giveFood(bob, carryingFood); // gives the food to the base
        
        if (energy < 500) askForEnergy(bob, 1500 - energy); // ask for energy if it lacks some
        
        // go back to "explore and collect" mode and make a half turn
        brain[4].x = 0;
        right(180);
      } 
      else {
        // if still away from the base head towards the base (with some variations) and try to move forward
        heading = towards(bob) + random(-radians(20), radians(20));
        tryToMoveForward();
      }
    }
  }

  //
  // goAndEat
  // ========
  // > go explore and collect food
  //
  void goAndEat() {
    Wall wally = (Wall)minDist(perceiveWalls()); // look for the closest wall
    Base bob = (Base)minDist(myBases); // look for the closest base
    if (bob != null) {
      float dist = distance(bob);
      if ((wally != null) && ((dist < basePerception - 1) || (dist > basePerception + 2))) takeWall(wally); // if wall seen and not at the limit of perception of the base then tries to collect the wall
      
    }

    // look for the closest burger
    Burger zorg = (Burger)minDist(perceiveBurgers());
    if (zorg != null) {
      // if there is one
      if (distance(zorg) <= 2) takeFood(zorg); // if next to it, collect it
      else {
        // if away from the burger, head towards it and try to move forward
        heading = towards(zorg) + random(-radians(20), radians(20));
        tryToMoveForward();
      }
    } 
    else if (brain[4].y == 1) {
      // if no burger seen but food localized (thank's to a message received)
      if (distance(brain[0]) > 2) {
        // head towards localized food and try to move forward
        heading = towards(brain[0]);
        tryToMoveForward();
      } 
      else brain[4].y = 0; // if the food is reached, clear the corresponding flag
    } 
    else {
      // if no food seen and no food localized, explore randomly
      heading += random(-radians(45), radians(45));
      tryToMoveForward();
    }
  }

  //
  // tryToMoveForward
  // ================
  // > try to move forward after having checked that no obstacle is in front
  //
  void tryToMoveForward() {
    if (!freeAhead(speed)) right(random(360)); // if there is an obstacle ahead, rotate randomly
    if (freeAhead(speed)) forward(speed); // if there is no obstacle ahead, move forward at full speed
  }

  //
  // handleMessages
  // ==============
  // > handle messages received
  // > identify the closest localized burger
  //
  void handleMessages() {
    float d = width;
    PVector p = new PVector();

    Message msg;
    // for all messages
    for (int i=0; i<messages.size(); i++) {
      // get next message
      msg = messages.get(i);
      // if "localized food" message
      if (msg.type == INFORM_ABOUT_FOOD) {
        // record the position of the burger
        p.x = msg.args[0];
        p.y = msg.args[1];
        if (distance(p) < d) {
          // if burger closer than closest burger, record the position in the brain, update the distance of the closest burger and update the corresponding flag
          brain[0].x = p.x;
          brain[0].y = p.y;
          
          d = distance(p);
          
          brain[4].y = 1;
        }
      }
    }
    
    flushMessages(); // clear the message queue
  }
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the green rocket launchers
//
///////////////////////////////////////////////////////////////////////////
// map of the brain:
//   0.x / 0.y = position of the target
//   0.z = breed of the target
//   4.x = (0 = look for target | 1 = go back to base) 
//   4.y = (0 = no target | 1 = localized target)
///////////////////////////////////////////////////////////////////////////
class GreenRocketLauncher extends RocketLauncher implements GreenRobot {
  //
  // constructor
  // ===========
  //
  GreenRocketLauncher(PVector pos, color c, ArrayList b, Team t) {
    super(pos, c, b, t);
  }

  //
  // setup
  // =====
  // > called at the creation of the agent
  //
  void setup() {
  }

  //
  // go
  // ==
  // > called at each iteration of the game
  // > defines the behavior of the agent
  //
  void go() {
    // if no energy or no bullets
    if ((energy < 100) || (bullets == 0)) brain[4].x = 1; // go back to the base

    if (brain[4].x == 1) {
      // if in "go back to base" mode
      goBackToBase();
    } 
    else {
      // try to find a target
      selectTarget();
      if (target()) launchBullet(towards(brain[0])); //if target identified shoot on the target
      else randomMove(45); // else explore randomly
    }
  }

  //
  // selectTarget
  // ============
  // > try to localize a target
  //
  void selectTarget() {
    // look for the closest ennemy robot
    Robot bob = (Robot)minDist(perceiveRobots(ennemy));
    if (bob != null) {
      // if one found, record the position and breed of the target
      brain[0].x = bob.pos.x;
      brain[0].y = bob.pos.y;
      brain[0].z = bob.breed;
      // locks the target
      brain[4].y = 1;
    } 
    else brain[4].y = 0; // else if no target found
  }

  //
  // target
  // ======
  // > checks if a target has been locked
  //
  // output
  // ------
  // > true if target locket / false if not
  //
  boolean target() {
    return (brain[4].y == 1);
  }

  //
  // goBackToBase
  // ============
  // > go back to the closest base
  //
  void goBackToBase() {
    // look for closest base
    Base bob = (Base)minDist(myBases);
    if (bob != null) {
      // if there is one, compute its distance
      float dist = distance(bob);

      if (dist <= 2) {
        // if next to the base
        if (energy < 500) askForEnergy(bob, 1500 - energy); // if energy low, ask for some energy
        
        brain[4].x = 0;// go back to "exploration" mode and make a half turn
        right(180);
      } 
      else {
        // if not next to the base, head towards it and try to move forward 
        heading = towards(bob) + random(-radians(20), radians(20));
        tryToMoveForward();
      }
    }
  }

  //
  // tryToMoveForward
  // ================
  // > try to move forward after having checked that no obstacle is in front
  //
  void tryToMoveForward() {
    if (!freeAhead(speed)) right(random(360)); // if there is an obstacle ahead, rotate randomly
    if (freeAhead(speed)) forward(speed); // if there is no obstacle ahead, move forward at full speed
  }
}
