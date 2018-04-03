
# coding: utf-8

# Key 1: 6bfdae152ec04b8db88d932c0bc0a4c9
# 
# Key 2: da0b35cb86434e8f93f5ca12b2997cc8

# #AZURE PASS KEYS
# Key 1: ce2b24ee78624530a94bb5fd79bec2eb
# Key 2: a8d0659b33bd4099a42ac9251d742f99

# In[1]:

import cognitive_face as CF


fb_ids = [("100008532641869","Venkatesh Sivaraman"),("100006541209232","Karunya Sethuraman"),
          ("100001019659920","Rene Garcia"),("100002495596576","Mira Partha"),("100003239273542","Samyu Yagati"),
          ("100003046714844","Noah Moroze"),("100002460778633","Michael Zhang"),("100007818076486","Kavya Ravi")]

# In[2]:

def detect_face(img_url):
    '''returns the id,location of the face within the image'''
    return CF.face.detect(img_url)


# In[3]:

def break_into_10s(list_of_faces):
    out = []
    a = len(list_of_faces)//10
    if len(list_of_faces)/10 != a:
        a+=1
    for i in range(a):
        out.append(list_of_faces[10*i:10*i+10])
    return out


# In[4]:

def imgurl_to_output_suggestions(img, name_of_group):
    faces = detect_face(img)
    tens_of_faces = break_into_10s(faces)
    output_suggestions = []
    for i in tens_of_faces:
        output_suggestions.append(CF.face.identify([j['faceId'] for j in i],name_of_group))
    for i in range(len(output_suggestions)):
        for o in output_suggestions[i]:
            for j in faces:
                if o['faceId'] == j['faceId']:
                    o['faceRectangle'] = j['faceRectangle']
    return output_suggestions


# In[5]:

def process_output_suggestions(output_suggestions):
    outputs = []
    for x in range(len(output_suggestions))
        for i in output_suggestions[x]:
            cand = i['candidates']
            f_id = i['faceId']
            rect = i['faceRectangle']
            conf_cand = []
            if cand!=[]:
                for j in cand:
                    conf_cand.append((j['confidence'],j['personId']))
            if conf_cand == []:
                outputs.append((None,f_id))
            else:
                m_conf = 0
                for c in conf_cand:
                    if m_conf<c[0]:
                        m_conf = c[0]
                for c in conf_cand:
                    if c[0] == m_conf:
                        p_id = c[1]
                outputs.append((CF.person.get(name_of_group,p_id)['name'],f_id,rect))
    return outputs


# In[17]:

def clean_up(output):
    actual_output = []
    for i in output:
        if i[0]!=None:
            for x in fb_ids:
                if i[0] in x[1]:
                    fb_id = x[0]
            actual_output.append((i[0],i[1],fb_id))
    return actual_output


# In[18]:

def identify_friends(img_path):
    KEY = 'ce2b24ee78624530a94bb5fd79bec2eb' #primary
    CF.Key.set(KEY)

    BASE_URL = 'https://eastus.api.cognitive.microsoft.com/face/v1.0/' # Replace with your regional Base URL
    CF.BaseUrl.set(BASE_URL)

    img_path = '' #path at which the image sent to server is hosted
    name_of_group = 'kavya_friends_1'
    o_s = imgurl_to_output_suggestions(img_url,name_of_group)
    out = process_output_suggestions(o_s)
    return clean_up(out)


# In[13]:

