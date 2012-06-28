local like = minetest.require("madblocks","like")("hydroponics")
local growing = minetest.require("nature","growing")

function imageExists(image)
   file = minetest.requiretools.loadResource("hydroponics","textures".."/"..image)
   if file then
      file:close()
      return true
   end
   error("Image not found for hydroponics: "..image)
end

local plants = {
   tomato = {},
   peas = {},
   habanero = {},
   cyanflower = {},
   magentaflower = {},
   yellowflower = {},
   rubberplant = {short=true, give_on_harvest='hydroponics:rubber'},
   grapes = {permaculture=true},
   coffee = {permaculture=true},
   roses = {give_on_harvest='hydroponics:rosebush'}                          
}

like.glow('growlamp','Growlamp','plantlike')
-- promix is just a hack to keep cultivated plants from growing on
-- regular dirt!
minetest.register_node("hydroponics:promix", {
                          description = "Promix",
                          tile_images = {"hydroponics_promix.png"},
                          is_ground_content = true,
                          groups = {crumbly=3},
                          sounds = default.node_sound_dirt_defaults(),
                       })

steps = {}
function start()
   for name,plant in pairs(plants) do 
      local identifier = "hydroponics:wild_"..name
      
      minetest.register_node(
         identifier, 
         {
            description = "Wild Plant",
            drawtype = "plantlike",
            visual_scale = 1.0,
            tile_images = {"hydroponics_wildplant.png"},
            paramtype = "light",
            walkable = false,
            groups = {snappy=3,flammable=3},
            sounds = default.node_sound_leaves_defaults(),
            drop = 'hydroponics:seeds_'..name..' 4',
            selection_box = {
               type = "fixed",
               fixed = {-1/3, -1/2, -1/3, 1/3, 1/6, 1/3},
            },
         })
      growing.add(identifier)
      local function registerGrowthStage(stage,nextStage,lightNeeded)
         local identifier = "hydroponics:"..name.."_"..stage
         if steps[stage] == nil then
            steps[stage] = {identifier}
         else
            table.insert(steps[stage],identifier)
         end
         local image = nil
         local info = {
            description = name.." "..stage,
            paramtype = "light",
            walkable = false,
            groups = {snappy=2},
         }
         if stage == "seeds" then
            info.groups.choppy = 2
            info.groups.oddly_breakable_by_hand = 3
            info.is_ground_content = true
            info.drawtype = "signlike"
            info.paramtype2 = "wallmounted"
            info.legacy_wall_mounted = true
            info.climbable = false
            info.selection_box = {
               type = "wallmounted",
               --wall_top = = <default>
               --wall_bottom = = <default>
               --wall_side = = <default>
            }
            info.sounds = default.node_sound_wood_defaults()
            image = "hydroponics_seeds.png"
         else
            local n = tonumber(stage)
            info.drawtype = "plantlike"
            info.visual_scale = 1.0
            info.sunlight_propagates = true
            info.climbable = true
            info.furnace_burntime = n

            if n ~= nil then
               if n > 1 and plant.growtype == 'permaculture' then
                  plant.growtype = 'growshort'
                  -- permaculture don't die when you dig them, just turn young again!
                  info.on_dig = 
                     function(pos,node)
                        minetest.env:add_node(pos,{type='node',name='hydroponics:'..name..'1'})
                     end
               end
               image = "hydroponics_"..name..stage..".png"
            else
               image = "hydroponics_"..stage..".png"
            end

            if n == 4 then
               local harvest = plant.give_on_harvest or 'hydroponics:'..name
               info.drop = {
                  items = {
                     {
                        items = {"hydroponics:"..name.."_seeds".." 4"},
                        rarity = 6,
                     },
                     {
                        items = {harvest.." 4"}
                     }
                  }
               }
            else
               -- transplanting
               info.drop = identifier
               -- grow into the next stage (possibly w/ earlier stage above)
               minetest.register_abm(
                  {
                     nodenames = { identifier },
                     interval = growing.growInterval/4,
                     chance = 10/8,
                     action = 
                        function(pos, node, active_object_count, active_object_count_wider)
                           local light = minetest.env:get_node_light(pos, nil)
                           if (light and light < lightNeeded) then
                              return
                           end
                           local mix = pos.y - 1
                           local foundMix = false;
                           for i = 1,3,1 do
                              mix = mix - 1
                              local node = minetest.env:get_node(
                                 {x=pos.x,y=mix,z=pos.z}).name
                              -- only grow if there is a (short enough)
                              -- line of your plant straight to the promix
                              if node == "hydroponics:promix" then 
                                 foundMix = true
                                 break
                              end
                              if node:sub(1,0xd) == "default:dirt" or node:sub(1,0xc) == "nature:grass" then
                                 -- don't grow as well off of promix
                                 if math.random(4)>1 then return end
                                 foundMix = true
                                 break
                              end
                              if not node:sub(1,0xc)=="hydroponics:" then return end
                              if not node:sub(0xc,0xc+#name)==name then return end
                           end
                           if not foundMix then return end                     
                           local water = {pos.x,mix.y-2,pos.z}
                           if minetest.env:get_node(water).groups.water == nil then
                              return
                           end
                           -- water directly below the mix, everything's perfect.

                           local which = "hydroponics:"..name.."_"..nextStage
                           minetest.env:add_node(pos,{type="node",name=which})
                           if plant.short then return end
                           local above = {pos.x,pos.y+1,pos.z}
                           if minetest.env:get_node(above).name ~= "air" then
                              return
                           end
                           minetest.env:add_node(above,{type="node",name=identifier})                          
                        end 
                  })
            end
         end
         imageExists(image)
         info.tiles = { image }
         info.inventory_image = image
         info.wield_image = image

         minetest.register_node(identifier,info)
      end

      registerGrowthStage("seeds","seedlings",1)
      registerGrowthStage("seedlings","sproutlings",2)
      registerGrowthStage("sproutlings",1,3)
      registerGrowthStage(1,2,3)
      registerGrowthStage(2,3,4)
      registerGrowthStage(3,4,3)
      

      if plant.give_on_harvest == nil then
         local bare = "hydroponics:"..name
         minetest.register_node(
            bare,
            {
               description = name,
               drawtype = "plantlike",
               visual_scale = 1.0,
               tile_images = {"hydroponics_"..name..".png"},
               inventory_image = "hydroponics_"..name..".png",
               paramtype = "light",
               sunlight_propagates = true,
               walkable = false,
               groups = {fleshy=3,dig_immediate=3,flammable=2},
               on_use = minetest.item_eat(4),
               sounds = default.node_sound_defaults(),
            })
      end
   end
end

for i,flower in ipairs({"yellow","cyan","magenta"}) do
   growing.add("hydroponics:"..flower.."flower")
end

local s = nil
for n,v in pairs(plants) do
   if s == nil then
      s = "Hydroponics: "..n
   else
      s = s..", "..n
   end
end
print(s)

local postinit = minetest.require("__builtin","postinit")
-- postinit is kind of funny. 
-- hydroponics depends on growing so hydroponics should go first
postinit.push(start,"hydroponics","growing")