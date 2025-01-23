/////////////////////////////////////////////////////////////////////////// //<>// //<>// //<>//
//
// The code for the green team
// ===========================
//
///////////////////////////////////////////////////////////////////////////


final int HARVESTER_INFORM_FULL = 1234;
final int BASE_ASK_ASSITANT = 2808;

final int numberOfBaseHarvester = 1;
final int numberOfSentinel = 0;
final float maxProtectionDistance = 10;


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
    // 6 harvesters, 0 rockets launchers, 5 explorers
    brain[5].x = 6;
    brain[5].y = 0;
    brain[5].z = 3;
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
    else if(energy>12000){
        ArrayList<Seed> seeds = perceiveSeeds(friend);
        ArrayList<Burger> burgers = perceiveBurgers();

        if(seeds!=null && burgers!=null && burgers.size()>seeds.size()*0.5f) brain[5].x++; // pas de graine donc on crée des harvester
        else if(seeds!=null && seeds.size()>50) brain[5].y++; // temps de richesse  donc on crée l'armée
        else {
          if ((int)random(2) == 0)
            // creates a new harvesterexplorer with 50% chance
            brain[5].z++;
          else if ((int)random(2) == 0)
            // creates a new rocket launcher with 25% chance
            brain[5].y++;
          else
            // creates a new explorer with 25% chance
            brain[5].x++;
        }
    }
        
        //newHarvester();
    
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
    DefineHomeAssitants();

    // creates new bullets and fafs if the stock is low and enought energy
    if ((bullets < 10) && (energy > 1000)) newFafs(10);
    if ((bullets < 10) && (energy > 1000)) newBullets(50); 

    // if ennemy rocket launcher in the area of perception
    Robot bob = (Robot)minDist(perceiveRobots(ennemy, LAUNCHER));
    Robot robot = (Robot)minDist(perceiveRobots(ennemy));
    if (bob != null) {
      heading = towards(bob);
      // launch a faf if no friend robot on the trajectory...
      launchFaf(bob);
      launchBullet(towards(bob));
    }
    else if(robot != null){
      heading = towards(robot);
      launchBullet(towards(robot));
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

  void DefineHomeAssitants(){
      ArrayList<RocketLauncher> rockets = perceiveRobots(friend, LAUNCHER);
      if(rockets != null && rockets.size() <= numberOfSentinel) {
        for(RocketLauncher rocket : rockets ){
          float[] args = new float[0];
          sendMessage(rocket.who,BASE_ASK_ASSITANT, args);
        }
      }
      
      ArrayList<Harvester> harvesters = perceiveRobots(friend, HARVESTER);
      if(harvesters != null && harvesters.size() <= numberOfBaseHarvester) {
        for(Harvester harvester : harvesters ){
          float[] args = new float[0];
          sendMessage(harvester.who,BASE_ASK_ASSITANT, args);
        }
      }
  }
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the green explorers
//
///////////////////////////////////////////////////////////////////////////
// map of the brain:
//   4.x = (0 = exploration | 1 = go back to base | 2 = stay on food)
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
    handleMessages();

    if ((carryingFood > 200) || (energy < 100)) brain[4].x = 1; // if food to deposit or too few energy then time to go back to base

    if(brain[4].x == 2) { 
      // stay on food 
      if(perceiveBurgers() == null) brain[4].x = 0;
    }
    // depending on the state of the robot
    else if (brain[4].x == 1) { 
      goBackToBase(); // go back to base...
    } 
    else {
      // or else explore randomly
      heading += random(-radians(45), radians(45)); // randomly computes the new heading
      if (freeAhead(speed, collisionAngle)) forward(speed); // if the environment is free ahead of the robot then move forward at full speed
      else 
      {
        heading += radians(45);
      }
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
      brain[4].x = 2;
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
      if (explo != null) informAboutTarget(explo, babe); // if one is seen, send a message with the localized ennemy base
      Base basy = (Base)oneOf(perceiveRobots(friend, BASE));
      if (basy != null) informAboutTarget(basy, babe); // if one is seen, send a message with the localized ennemy base
      RocketLauncher friendlyRocket = (RocketLauncher)oneOf(perceiveRobots(friend, LAUNCHER));
      if (friendlyRocket != null) informAboutTarget(friendlyRocket, babe); // if one is seen, send a message with the localized ennemy base
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


  //
  // handleMessages
  // ==============
  // > handle messages received
  // > identify the closest localized burger
  //
  void handleMessages() {

    Message msg;
    // for all messages
    for (int i=0; i<messages.size(); i++) {
      // get next message
      msg = messages.get(i);
      // if "localized full harvester" message
      if (msg.type == HARVESTER_INFORM_FULL) {
        brain[0].x = msg.args[0];
        brain[1].x = msg.args[1];
        heading = towards(brain[0]);
        tryToMoveForward();

        Harvester bob = (Harvester)oneOf(perceiveRobots(friend, HARVESTER));
        askForEnergy(bob, 1500 - energy);
      }
      
    }
    // clear the message queue
    flushMessages();
  }

  void askForEnergy(Robot bob, float qty) {
    // check that bob is a base and distance is less than max range
    if ((bob != null) && (distance(bob) < messageRange)) {
      // build the message...
      float[] args = new float[1];
      args[0] = qty;
      Message msg = new Message(ASK_FOR_ENERGY, who, bob.who, args);
      // ...and add it to bob's messages queue
      bob.messages.add(msg);
    }
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
//   3.x = (0 = not Assitant | is Assitant )
//   3.y = id of home base
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
    if (carryingFood > 200) harvesterInformFull();
    // if in "go back" state
    if (brain[4].x == 1) {
      goBackToBase(); // go back to the base

      // if the robot enough has energy and food
      if ((energy > 100) && (carryingFood > 100)) {
        Base bob = (Base)minDist(myBases); // check for closest base
        if (bob != null) {
          // if there is one and the harvester is in the sphere of perception of the base
          if (distance(bob) < basePerception / 1.5) plantSeed(); // plant one burger as a seed to produce new ones
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
      // if ((dist > basePerception) && (dist < basePerception + 1)) dropWall(); // if at the limit of perception of the base, drops a wall (if it carries some)
 
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
    float dist= 999999999;
    if (bob != null) {
      dist = distance(bob);
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
    else if (brain[3].x == 1 && dist > maxProtectionDistance) {
      
      if(brain[3].y >= myBases.size()){
        brain[3].x = 0;
        return;
      }
      heading = towards((Base) myBases.get((int) brain[3].y)) + random(-radians(20), radians(20));
      tryToMoveForward();
      
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
      else if (msg.type == ASK_FOR_ENERGY) {
        // if the message is a request for energy
        if (energy > 1000 + msg.args[0]) {
          Robot alice = game.getRobot(msg.alice);
          this.energy -= msg.args[0];
          alice.energy += msg.args[0];
        }
      }
      else if (msg.type == BASE_ASK_ASSITANT){
        brain[3].x = 1;
        brain[3].y =  myBases.indexOf(minDist(myBases));
        // éléphant
      } 
    }
    
    flushMessages(); // clear the message queue
  }


  void harvesterInformFull(){
    Explorer bob = (Explorer)oneOf(perceiveRobots(friend, EXPLORER));
    // check that bob exists and distance is less than max range
    if ((bob != null) && (distance(bob) < messageRange)) {
      float[] args = new float[2];
      args[0]=pos.x;
      args[1]=pos.y;
      sendMessage(bob.who, HARVESTER_INFORM_FULL, args);
    }
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
//   3.x = (0 = not defending | 1 = is defending the base)
//   4.x = (0 = look for target | 1 = go back to base | 2 = is defending the base) 
//   4.y = (0 = no target | 1 = localized target)
//   4.z = (0 = no request target | 1 = got target request)
//   1.xy base position
//   1.z has base position
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
    // handle messages received
    handleMessages();

    // if no energy or no bullets
    if ((energy < 300) || (bullets == 0)) brain[4].x = 1; // go back to the base

    if (brain[4].x == 1) {
      // if in "go back to base" mode
      goBackToBase();
    } 
    else if (brain[1].z == 1) {
          if(distance(new PVector(brain[1].x,brain[1].y))<5) tryToShoot();
          else {
            heading = towards(brain[1]) + random(-radians(20), radians(20));
            tryToMoveForward();
          }
    }
    else if (brain[3].x == 1) {
      Base bob = (Base)minDist(myBases);
      if (bob != null) { 
        float dist = distance(bob);

        if (dist <= maxProtectionDistance) {
          tryToShoot();
        } 
        else {
          heading = towards(bob) + random(-radians(20), radians(20));
          tryToMoveForward();
        }
      }

    }
    else if (brain[4].z == 1){
      // move towards the target
      heading = towards(brain[0]);
      tryToMoveForward();
      if (distance(brain[0]) < 5) {
        // if next to the target, shoot
        tryToShoot();
        brain[4].z = 0; // clear the target flag
      }
    } else {
      tryToShoot();
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
        if (energy < 1500) askForEnergy(bob, 1500 - energy); // if energy low, ask for some energy
        
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
      // if "localized target" message
      if (msg.type == INFORM_ABOUT_TARGET) {
        // record the position of the target
        p.x = msg.args[0];
        p.y = msg.args[1];
        if (distance(p) < d) {
          // if target closer than closest target
          // record the position in the brain
          brain[0].x = p.x;
          brain[0].y = p.y;
          // update the distance of the closest target
          d = distance(p);
          // update the corresponding flag
          brain[4].z = 1;
        }
      }
      else if( msg.type == BASE_ASK_ASSITANT) {
        brain[3].x = 1;
      }
    }
    // clear the message queue
    flushMessages();
  }

  void tryToShoot(){
      // try to find a target
      
      Base base = (Base)minDist(perceiveRobots(ennemy,BASE));
      if(base != null){
        brain[1].x = base.pos.x;
        brain[1].y = base.pos.y;
        brain[1].z = 1;
        launchBullet(towards(base));
        return;
      }

      PVector basePose = new PVector(brain[1].x,brain[1].y);
      if(brain[1].z == 1 && distance(basePose) < 5 && base == null) brain[1].z = 0;

      
      selectTarget();
      if (target()){
        Robot bob = (Robot)minDist(perceiveRobots(ennemy)); 
        if(distance(bob) < 1.0f){
          right(180);
          forward(1.0f);
        }
        launchBullet(towards(brain[0])); //if target identified shoot on the target
      } 
      else randomMove(45); // else explore randomly
  }
}
