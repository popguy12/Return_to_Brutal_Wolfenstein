// projectile bullets, based on PB ones
Class BW_Projectile : fastprojectile
{
    default
    {
        speed 200;
        +missile;
        radius 2;
        height 2;
		renderstyle "Add";
		//damage 5;
		damage 0;
		//damagefunction inflictDamage(5);
		//+ripper
		BW_Projectile.ripAmount 0;
		BW_Projectile.projectiledmg 5;
		damagetype "Bullet";
    }
	
	states
	{
		spawn:
			TNT1 A 1;
			TRAC A -1 bright;
			stop;
	}
	
	int ripAmount, basedamage;
	property ripAmount:ripAmount;
	property projectiledmg:basedamage;
	
	vector3 initpos;
	actor LastActor;
	int maxrip;
	vector2 lastview;
	
	int GetProjectileDamage()
	{
		if(!bripper)
			return basedamage;
		
		double half = basedamage * 0.5;
		double adddmg = half/max(1,maxrip);
		adddmg *= ripAmount + 1;
		return int(half + adddmg);
	}

	override void postbeginplay()
	{
		super.postbeginplay();
		initpos = pos;
		maxrip = ripAmount;
		if(target)
			lastview = (target.angle,target.pitch);
		
	}
    override void tick()
    {
        BW_PJTick();
    }
	
	void HitActor(actor victim)
	{
		int dmg = GetProjectileDamage();
		int scaled_damage = victim.GetModifiedDamage(damagetype,dmg,true,self,target);
		
		if(victim.bsolid || victim.bshootable)
		{
			if(victim.bNOBLOOD || victim.bINVULNERABLE || victim.bDORMANT || 
			victim.bREFLECTIVE || (victim.bsolid && ! victim.bShootable))
				SpawnPuff("Bulletpuff", pos, angle, 0, 0, PF_HITTHING);
			else
				victim.SpawnBlood( pos, angle, ceil(scaled_damage) );
		}
		
		victim.DamageMobj(self,target,scaled_damage,damagetype,0,angle);
	}

	//from pb too
	override int SpecialMissileHit(Actor victim)
	{
		if (victim == Target && !bHitOwner  || (!victim.bSHOOTABLE && (target && target.player)))
		{
			return 1; //[inkoalawetrust] //This is default behavior though ?
		}
		
		if (bRIPPER)
		{
			if (ripAmount < 0)
			{
				//console.printf("destroying due to no rips");
				return 0; // [Ace] We must use 0 here or else the projectile will keep ripping. Removing the ripper flag does not take effect until the next tic because of how ripping works.
				
			}
			if (Victim && LastActor != victim)
			{
				ripAmount--;
				//Handle_MissileHit(victim);
				HitActor(victim);
				LastActor = victim;
				//console.printf("Hitting: %s (%d rips remain)",victim.getclassname(),ripAmount);
			}
			else
			{
				return 1;
			}
		}
		Return -1;
	}

    void BW_PJTick ()
	{
		ClearInterpolation();
		double oldz = pos.Z;

		if (isFrozen())
			return;

		// [RH] Ripping is a little different than it was in Hexen
		FCheckPosition tm;
		tm.DoRipping = bRipper;

		int count = 8;
		if (radius > 0)
		{
			while (abs(Vel.X) >= radius * count || abs(Vel.Y) >= radius * count)
			{
				// we need to take smaller steps.
				count += count;
			}
		}

		if (height > 0)
		{
			while (abs(Vel.Z) >= height * count)
			{
				count += count;
			}
		}

		// Handle movement
		bool ismoved = Vel != (0, 0, 0)
			// Check Z position set during previous tick.
			// It should be strictly equal to the argument of SetZ() function.
			|| (   (pos.Z != floorz           ) /* Did it hit the floor?   */
				&& (pos.Z != ceilingz - Height) /* Did it hit the ceiling? */ );

		if (ismoved)
		{
			// force some lateral movement so that collision detection works as intended.
			if (bMissile && Vel.X == 0 && Vel.Y == 0 && !IsZeroDamage())
			{
				VelFromAngle(MinVel);
			}

			Vector3 frac = Vel / count;
			int changexy = frac.X != 0 || frac.Y != 0;
			int ripcount = count / 8;
			for (int i = 0; i < count; i++)
			{
				if (changexy)
				{
					if (--ripcount <= 0)
					{
						tm.ClearLastRipped();	// [RH] Do rip damage each step, like Hexen
					}
					
					if (!TryMove (Pos.XY + frac.XY, true, false, tm))
					{ // Blocked move
						if (!bSkyExplode)
						{
							let l = tm.ceilingline;
							if (l &&
								l.backsector &&
								l.backsector.GetTexture(sector.ceiling) == skyflatnum)
							{
								let posr = PosRelative(l.backsector);
								if (pos.Z >= l.backsector.ceilingplane.ZatPoint(posr.XY))
								{
									// Hack to prevent missiles exploding against the sky.
									// Does not handle sky floors.
									Destroy ();
									return;
								}
							}
							// [RH] Don't explode on horizon lines.
							if (BlockingLine != NULL && BlockingLine.special == Line_Horizon)
							{
								Destroy ();
								return;
							}
						}
						BW_SpawnImpact(TRACE_HitWall,CurSector,BlockingLine);
                        ExplodeMissile (BlockingLine, BlockingMobj);
						return;
					}
				}
				AddZ(frac.Z);
				UpdateWaterLevel ();
				oldz = pos.Z;
				if (oldz <= floorz)
				{ // Hit the floor

					if (floorpic == skyflatnum && !bSkyExplode)
					{
						// [RH] Just remove the missile without exploding it
						//		if this is a sky floor.
						Destroy ();
						return;
					}
					
					BW_SpawnImpact(TRACE_HitFloor,CurSector,BlockingLine);
                    SetZ(floorz);
					HitFloor ();
                    Destructible.ProjectileHitPlane(self, SECPART_Floor);
					ExplodeMissile (NULL, NULL);
					return;
				}
				if (pos.Z + height > ceilingz)
				{ // Hit the ceiling

					if (ceilingpic == skyflatnum && !bSkyExplode)
					{
						Destroy ();
						return;
					}
					
					BW_SpawnImpact(TRACE_HitCeiling,CurSector,BlockingLine);
                    SetZ(ceilingz - Height);
                    Destructible.ProjectileHitPlane(self, SECPART_Ceiling);
					ExplodeMissile (NULL, NULL);
					return;
				}
				CheckPortalTransition();
				if (changexy && ripcount <= 0) 
				{
					ripcount = count >> 3;

					// call the 'Effect' method.
					Effect();
				}
			}
		}
		if (!CheckNoDelay())
			return;		// freed itself
		// Advance the state
		if (tics != -1)
		{
			if (tics > 0) tics--;
			while (!tics)
			{
				if (!SetState (CurState.NextState))
				{ // mobj was removed
					return;
				}
			}
		}

    }

	//TRACE_HitWall,TRACE_HitCeiling,TRACE_HitFloor
    void BW_SpawnImpact(int type = 0, sector hitsector = null,line hitline = null)
    {
        if(bRipper && ripAmount < 0)	//was destroying after ripping enough enemies, stop here to avoid errors
			return;
		name mat = 'default';
		string tex;
		vector3 normal;
		int impc = 0;
		double wallAng;
		vector3 hitdir = levellocals.vec3diff(initpos,pos).unit();
		//setorigin((pos - hitdir),false);
		FLineTraceData t;
		bool hit = self.linetrace(lastview.x,10,lastview.y,TRF_THRUACTORS,1,-2,0,t);	//probably the easier approach
		
		/*if(!hit)
		{
			console.printf("fuck you");
		}*/

		/*switch(type)
        {
            case TRACE_HitWall: //wall
				if(!hitline)
				{
					if(BlockingCeiling)
					{
						
						tex	= texman.getname(ceilingpic);
						mat = BW_StaticHandler.getmaterialname(tex);
						normal = hitsector.ceilingplane.normal;
						impc = BW_impactpuff.IMP_CEIL;
					}
					else if(BlockingFloor)
					{
						tex = texman.getname(floorpic);//floorpic
						mat = BW_StaticHandler.getmaterialname(tex);
						normal = hitsector.floorplane.normal;
						impc = BW_impactpuff.IMP_FLOOR;
					}
					else
					{
						console.printf("Error: no line found!");
						return;
					}
					
				}

				int sd = levellocals.PointOnLineSide(target.pos.xy,hitline,true);
				TextureID tx = PB_GetLineTex(hitline,sd,pos.z);
				tex = texman.getname(tx);
                mat = BW_StaticHandler.getmaterialname(tex);

				vector2 nrm = GetLineNormal(sd,HitLine);
				double wn = -atan2(nrm.x, nrm.y);
				normal = (RotateVector((0, 1),wn), 0);
				wallAng = wn;
				impc = BW_impactpuff.IMP_WALL;
                break;

            case TRACE_HitCeiling: //ceilling
				if(!hitsector)
				{
					console.printf("Error: no sector found!");
					return;
				}
				tex	= texman.getname(ceilingpic);//ceilingpic
				mat = BW_StaticHandler.getmaterialname(tex);
				normal = hitsector.ceilingplane.normal;
				impc = BW_impactpuff.IMP_CEIL;
                break;
            case TRACE_HitFloor: //floor 
				if(!hitsector)
				{
					console.printf("Error: no sector found!");
					return;
				}
				tex = texman.getname(floorpic);//floorpic
				mat = BW_StaticHandler.getmaterialname(tex);
				normal = hitsector.floorplane.normal;
				impc = BW_impactpuff.IMP_FLOOR;
				break;
        }*/
		

		tex = texman.getname(t.HitTexture);
        mat = BW_StaticHandler.getmaterialname(tex);
		//console.printf("Hit TYpe: %d",t.HitType);
		switch(t.HitType)
        {
            case TRACE_HitWall: //wall
				if(!t.HitLine)
				{
					console.printf("Error: no line found!");
					return;
					
				}

				//int sd = levellocals.PointOnLineSide(target.pos.xy,t.HitLine,true);
				
				//TextureID tx = PB_GetLineTex(t.HitLine,t.LineSide,t.hitlocation.z);
				//tex = texman.getname(t.HitTexture);
               // mat = BW_StaticHandler.getmaterialname(tex);
				vector2 nrm = GetLineNormal(t.LineSide,t.HitLine);
				double wn = -atan2(nrm.x, nrm.y);
				normal = (RotateVector((0, 1),wn), 0);
				wallAng = wn;
				impc = BW_impactpuff.IMP_WALL;
                break;

            case TRACE_HitCeiling: //ceilling
				if(!t.HitSector)
				{
					console.printf("Error: no sector found!");
					return;
				}
				//tex	= texman.getname(t.HitTexture);//texman.getname(ceilingpic);//ceilingpic
				//mat = BW_StaticHandler.getmaterialname(tex);
				normal = t.HitSector.ceilingplane.normal;
				impc = BW_impactpuff.IMP_CEIL;
                break;
            case TRACE_HitFloor: //floor 
				if(!t.HitSector)
				{
					console.printf("Error: no sector found!");
					return;
				}
				//tex = texman.getname(t.HitTexture);//texman.getname(floorpic);//floorpic
				//mat = BW_StaticHandler.getmaterialname(tex);
				normal = t.hitsector.floorplane.normal;
				impc = BW_impactpuff.IMP_FLOOR;
				break;
			default:
			case TRACE_HitNone:
				break;
        }

		if(mat != 'null')
		{
			let puff =  BW_impactpuff(spawn("BW_impactpuff",pos - hitdir));
			if(puff)
			{
				puff.tp = mat;
				puff.norm = normal;
				puff.impctDir = hitdir;
				puff.wang = wallAng;
				puff.impactType = impc;
				//console.printf("spawned the fucking puff");
				let sd = BW_StaticHandler.getmaterialSound(tex);
				if(sd)
					puff.A_Startsound(sd);
			}
		}
		else
		{
			if(!tex)
				return;
			console.printf("[\caBW Materials\c-]: texture \cd"..tex.."\c- not found in level \cd"..level.Mapname.."\c- at pos \cd"..pos.."\c-");
			let pf = spawn("BulletPuff",pos - hitdir,ALLOW_REPLACE);
			if(pf)
				pf.A_Spraydecal("BulletChip",30,(0,0,0),hitdir);
		}
		

    }

	//this comes from PB, 
	TextureID PB_GetLineTex(Line refLine, bool lineSide, double zPos)
	{
		sector backsec, frontsec;
		TextureID surfaceTexId;

		// [gng] ideally front would be the only side i need, but
		// some maps have weird lines where the front faces the back
		if(lineSide == 0)
		{
			backsec = BlockingLine.backsector;
			frontsec = BlockingLine.frontsector;
		}
		else
		{
			backsec = BlockingLine.frontsector;
			frontsec = BlockingLine.backsector;
		}

		side refSide = refLine.sidedef[lineSide];

		if(refSide)
		{
			if(!backsec)
				surfaceTexId = refSide.GetTexture(refSide.mid);
			else if(backsec.floorplane.ZAtPoint(pos.xy) >= zPos)
				surfaceTexId = refSide.GetTexture(refSide.bottom);
			else if (backsec.ceilingplane.ZAtPoint(pos.xy) <= zPos)
				surfaceTexId = refSide.GetTexture(refSide.top);
		}

		return surfaceTexId;
	}

	vector2 GetLineNormal(int iSide, Line vLine)
	{
		vector2 lineNormal = (-vLine.delta.y, vLine.delta.x).Unit();

		if(!iSide)
			lineNormal *= -1;

		return lineNormal;
	}


}

Class BW_LugerBullets : BW_Projectile
{
	default
	{
		BW_Projectile.projectiledmg 25;
		BW_Projectile.ripAmount 0;
		damagetype "ApistolaDamage";
	}
}