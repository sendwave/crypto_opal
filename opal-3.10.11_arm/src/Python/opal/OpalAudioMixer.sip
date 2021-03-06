/*
 * Python bindings.
 *
 * Open Phone Abstraction Library (OPAL)
 *
 * Copyright (c) 2011 Demetrius Cassidy
 *
 * The contents of this file are subject to the Mozilla Public License
 * Version 1.0 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
 * the License for the specific language governing rights and limitations
 * under the License.
 *
 * The Original Code is Open Phone Abstraction Library (OPAL)
 *
 * The Initial Developer of the Original Code is Demetrius Cassidy
 *
 * Contributor(s): ______________________________________.
 *
 * $Revision: 26117 $
 * $Author: rjongbloed $
 * $Date: 2011-07-04 22:45:05 -0500 (Mon, 04 Jul 2011) $
 */

%ModuleHeaderCode
#include <ptlib.h>
#include <opal/opalmixer.h>
%End


///////////////////////////////////////////////////////////////////////////////

/** Class base for a media mixer.

    The mixer operates by re-buffering the input media into chunks each with an
    associated timestamp. A main mixer thread then reads from each  stream at
    regular intervals, mixes the media and creates the output buffer.
 
    Note the timestamps of the input media are extremely important as they are
    used so that breaks or too fast data in the input media is dealt with correctly.
  */
class OpalBaseMixer /Abstract/
{
  public:
    OpalBaseMixer(
      bool pushThread,    ///< Indicate if the push thread should be started
      unsigned periodMS,  ///< The output buffer time in milliseconds
      unsigned periodTS   ///< The output buffer time in RTP timestamp units
    );

    virtual ~OpalBaseMixer();

    typedef PString Key_T;

    /**Add a stream to mixer using the specified key.
      */
    virtual bool AddStream(
      const Key_T & key   ///< key for mixer stream
    );

    /** Remove an input stream from mixer.
      */
    virtual void RemoveStream(
      const Key_T & key   ///< key for mixer stream
    );

    /** Remove all input streams from mixer.
      */
    virtual void RemoveAllStreams();

    /**Write an RTP data frame to mixer.
       A copy of the RTP data frame is created. This function is generally
       quite fast as the actual mixing is done in a different thread so
       minimal interference with the normal media stream processing occurs.
      */
    virtual bool WriteStream(
      const Key_T & key,          ///< key for mixer stream
      const RTP_DataFrame & input ///< Input RTP data for media
    );

    /**Read media from mixer.
       A pull model system would call this function to get the mixed media
       from the mixer. Note the stream indicated by the streamToIgnore key is
       not included in the mixing operation, allowing for example, the member
       of a conference to not hear themselves.

       Note this function is the function that does all the "heavy lifting"
       for the mixer.
      */
    virtual RTP_DataFrame * ReadMixed();
    virtual bool ReadMixed(RTP_DataFrame & mixed);

    /**Mixed data is now available.
       For a push model system, this is called with mixed data as returned by
       ReadMixed().

       The "mixed" parameter is a reference to a pointer, so if the consumer
       wishes to take responsibility for deleting the pointer to an RTP data
       frame, then they can set it to NULL.

       If false is returned then the push thread is exited.
      */
    virtual bool OnMixed(
      RTP_DataFrame * & mixed   ///, Poitner to mixed media.
    );

    /**Start the push thread.
       Normally called internally.
      */
    void StartPushThread();

    /**Stop the push thread.
       This will wait for th epush thread to terminate, so care must be taken
       to avoid deadlocks when calling.
      */
    void StopPushThread(bool lock = true);

    /**Get the period for mixing in RTP timestamp units.
      */
    unsigned GetPeriodTS() const;
};

///////////////////////////////////////////////////////////////////////////////

/** Class for an audio mixer.
    This takes raw PCM-16 data and sums all the input data streams to produce
    a single PCM-16 sample value.

    For 2 or less channels, they may be mixed as stereo where 16 bit PCM
    samples are placed in adjacent pairs in the output, rather than summing
    them.
  */
class OpalAudioMixer : OpalBaseMixer
{
  public:
    OpalAudioMixer(
      bool stereo = false,    ///< Indicate stero or mixed mono mode
      unsigned sampleRate = OpalMediaFormat::AudioClockRate, ///< Sample rate for audio, default 8kHz
      bool pushThread = true, ///< Indicate push thread is to be used
      unsigned period = 10    ///< Period for push/pull of audio from mixer in milliseconds
    );

    ~OpalAudioMixer();

    /** Remove an input stream from mixer.
      */
    virtual void RemoveStream(
      const Key_T & key   ///< key for mixer stream
    );

    /** Remove all input streams from mixer.
      */
    virtual void RemoveAllStreams();

    /**Return flag for mixing stereo audio data.
      */
    bool IsStereo() const;

    /**Get sample rate for audio.
      */
    unsigned GetSampleRate() const;

    /**Set sample rate for audio data.
       Note that all streams must have the same sample rate.

       Returns false if attempts to set sample rate to something different to
       existing streams.
      */
    bool SetSampleRate(
      unsigned rate   ///< New rate
    );

    /**Sets the size of the jitter buffer to be used by the specified stream
       in this mixer. A mixer defaults to not having any jitter buffer enabled.

       If either jitter delay parameter is zero, it destroys the jitter buffer
       attached to this mixer.
      */
    bool SetJitterBufferSize(
      const Key_T & key,       ///< key for mixer stream
      unsigned minJitterDelay, ///<  Minimum jitter buffer delay in RTP timestamp units
      unsigned maxJitterDelay  ///<  Maximum jitter buffer delay in RTP timestamp units
    );

  // protected:
    // struct AudioStream : OpalBaseMixer::Stream
    // {
      // AudioStream(OpalAudioMixer & mixer);
      // ~AudioStream();

      // virtual void QueuePacket(const RTP_DataFrame & rtp);
      // const short * GetAudioDataPtr();

      // OpalAudioMixer   & m_mixer;
      // OpalJitterBuffer * m_jitter;
      // unsigned           m_nextTimestamp;
      // PShortArray        m_cacheSamples;
      // size_t             m_samplesUsed;
    // };

    // virtual Stream * CreateStream();
    // virtual bool MixStreams(RTP_DataFrame & frame);
    // virtual size_t GetOutputSize() const;

    // void PreMixStreams();
    // void MixStereo(RTP_DataFrame & frame);
    // void MixAdditive(RTP_DataFrame & frame, const short * audioToSubtract);

};


///////////////////////////////////////////////////////////////////////////////


/**Video mixer.
   This takes raw YUV420P frames with a PluginCodec_Video_FrameHeader in the
   RTP data frames, scales them and places them in particular positions of the
   output data frame. A number of different patterns for positioning the sub
   images are available in the Styles enum.
  */
class OpalVideoMixer : OpalBaseMixer
{
  public:
    enum Styles {
      eSideBySideLetterbox, /**< Two images side by side with black bars top and bottom.
                                 It is expected that the input frames and output are all
                                 the same aspect ratio, e.g. 4:3. Works well if inputs
                                 are QCIF and output is CIF for example. */
      eSideBySideScaled,    /**< Two images side by side, scaled to fit halves of output
                                 frame. It is expected that the output frame be double
                                 the width of the input data to maintain aspect ratio.
                                 e.g. for CIF inputs, output would be 704x288. */
      eStackedPillarbox,    /**< Two images, one on top of the other with black bars down
                                 the sides. It is expected that the input frames and output
                                 are all the same aspect ratio, e.g. 4:3. Works well if
                                 inputs are QCIF and output is CIF for example. */
      eStackedScaled,       /**< Two images, one on top of the other, scaled to fit halves
                                 of output frame. It is expected that the output frame be
                                 double the height of the input data to maintain aspect
                                 ratio. e.g. for CIF inputs, output would be 352x576. */
      eGrid,                /**< Standard 2x2, 3x3, 4x4 grid pattern. Size of grid is
                                 dependent on the number of video streams. */
    };

    OpalVideoMixer(
      Styles style,           ///< Style for mixing video
      unsigned width,         ///< Width of output frame
      unsigned height,        ///< Height of output frame
      unsigned rate = 15,     ///< Frames per second for output
      bool pushThread = true  ///< A push thread is to be created
    );

    ~OpalVideoMixer();

    /**Get output video frame width.
      */
    unsigned GetFrameWidth() const;

    /**Get output video frame height.
      */
    unsigned GetFrameHeight() const;

    /**Get output video frame rate (frames per second)
      */
    unsigned GetFrameRate() const;

    /**Set output video frame rate.
       May be dynamically changed at any time.
      */
    bool SetFrameRate(
      unsigned rate   // New frames per second.
    );

    /**Set the output video frame width and height.
       May be dynamically changed at any time.
      */
    bool SetFrameSize(
      unsigned width,   ///< New width
      unsigned height   ///< new height
    );

  // protected:
    // struct VideoStream : OpalBaseMixer::Stream
    // {
      // VideoStream(OpalVideoMixer & mixer);
      // virtual void QueuePacket(const RTP_DataFrame & rtp);
      // void InsertVideoFrame(unsigned x, unsigned y, unsigned w, unsigned h);

      // OpalVideoMixer     & m_mixer;
    // };


    // virtual Stream * CreateStream();
    // virtual bool MixStreams(RTP_DataFrame & frame);
    // virtual size_t GetOutputSize() const;

};


///////////////////////////////////////////////////////////////////////////////


struct OpalMixerNodeInfo
{
  OpalMixerNodeInfo();

  virtual ~OpalMixerNodeInfo();

  virtual OpalMixerNodeInfo * Clone() const;

  PString  m_name;
  bool     m_listenOnly;
  unsigned m_sampleRate;
  bool     m_audioOnly;
  OpalVideoMixer::Styles m_style;
  unsigned m_width;
  unsigned m_height;
  unsigned m_rate;
};


///////////////////////////////////////////////////////////////////////////////


/** Mixer node manager.
    This class is a collection of OpalMixerNodes.
	It provides access to nodes by GUID or name.
  */
class OpalMixerNodeManager : PObject
{
  public:
  /**@name Construction */
  //@{
    /**Create a new mixer node manager.
     */
    OpalMixerNodeManager();

    /**Destroy all mixer nodes.
       Calls ShutDown.
     */
	virtual ~OpalMixerNodeManager();

    /**Shuts down, removes and destroys all mixer nodes.
      */
    virtual void ShutDown();

    /** Execute garbage collection of nodes.
        Returns PTrue if all garbage has been collected.
        Default behaviour deletes the objects that have been
		removed from the m_nodesByUID list.
      */
    virtual PBoolean GarbageCollection();
  //@}

  /**@name Operations */
  //@{
    /**Create a new node.
       This should create the new instance of the OpalMixerNode as required
       by the derived class, if any.
       The info variable should be created on the heap and it is subsequently
       owned by the node. NULL can be passed if defaults are to be used.
      */
    virtual OpalMixerNode * CreateNode(
      OpalMixerNodeInfo * info ///< Initial info for node
    );

	/**Add a new node.
       The info variable should be created on the heap and it is subsequently
       owned by the node. NULL can be passed if defaults are to be used.
	   Calls CreateNode.
      */
    // virtual PSafePtr<OpalMixerNode> AddNode(
      // OpalMixerNodeInfo * info ///< Initial info for node
    // );

    /**Add an existing node.
      */
    void AddNode(OpalMixerNode * node);

    /**Get the first node.
       The active nodes may be enumerated by the ++ operator on the PSafePtr.
      */
    // PSafePtr<OpalMixerNode> GetFirstNode(
      // PSafetyMode mode = PSafeReference ///< Lock mode for returned pointer
    // ) const;

    /**Find a new node.
       This will search for the mixer node using GUID and then name.
      */
    // virtual PSafePtr<OpalMixerNode> FindNode(
      // const PString & name,             ///< GUID or alias name for node
      // PSafetyMode mode = PSafeReference ///< Lock mode for returned pointer
    // );

    /**Remove a node.
       Shut down all active connections with node, remove its name 
	   associations and delete it.
      */
    virtual void RemoveNode(
      OpalMixerNode & node
    );

    /**Add node name to association list.
      */
    void AddNodeName(
      PString name,        ///< alias name for node
      OpalMixerNode * node ///< node associated with name
    );

    /**Remove node's name from association list.
      */
    void RemoveNodeName(
      PString name        ///< alias name for node
    );

    /**Remove list of node names from association list.
       Commonly used when node destroyed.
      */
    void RemoveNodeNames(
      PStringList names   ///< list of alias names for nodes
    );
  //@}

};


///////////////////////////////////////////////////////////////////////////////


/** Mixer EndPoint.
    This class represents an endpoint that mixes media. It can be used as the
    basis for a Multipoint Conferencing Unit.
 */
class OpalMixerEndPoint : OpalLocalEndPoint
{
  public:
  /**@name Construction */
  //@{
    /**Create a new endpoint.
     */
    OpalMixerEndPoint(
      OpalManager & manager,  ///<  Manager of all endpoints.
      const char * prefix     ///<  Prefix for URL style address strings
    );

    /**Destroy endpoint.
     */
    ~OpalMixerEndPoint();

    /**Shut down the endpoint, this is called by the OpalManager just before
       destroying the object and can be handy to make sure some things are
       stopped before the vtable gets clobbered.
      */
    virtual void ShutDown();
  //@}

  /**@name Overrides from OpalEndPoint */
  //@{
    /**Get the data formats this endpoint is capable of operating.
       This provides a list of media data format names that may be used by an
       OpalMediaStream may be created by a connection from this endpoint.

       Note that a specific connection may not actually support all of the
       media formats returned here, but should return no more.

       The default behaviour returns the most basic media formats, PCM audio
       and YUV420P video.
      */
    virtual OpalMediaFormatList GetMediaFormats() const;

    /**Set up a connection to a remote party.
       This is called from the OpalManager::MakeConnection() function once
       it has determined that this is the endpoint for the protocol.

       The general form for this party parameter is:

            [proto:][alias@][transport$]address[:port]

       where the various fields will have meanings specific to the endpoint
       type. For example, with H.323 it could be "h323:Fred@site.com" which
       indicates a user Fred at gatekeeper size.com. Whereas for the PSTN
       endpoint it could be "pstn:5551234" which is to call 5551234 on the
       first available PSTN line.

       The proto field is optional when passed to a specific endpoint. If it
       is present, however, it must agree with the endpoints protocol name or
       false is returned.

       This function usually returns almost immediately with the connection
       continuing to occur in a new background thread.

       If false is returned then the connection could not be established. For
       example if a PSTN endpoint is used and the assiciated line is engaged
       then it may return immediately. Returning a non-NULL value does not
       mean that the connection will succeed, only that an attempt is being
       made.

       The default behaviour is pure.
     */
    // virtual PSafePtr<OpalConnection> MakeConnection(
      // OpalCall & call,           ///<  Owner of connection
      // const PString & party,     ///<  Remote party to call
      // void * userData = NULL,    ///<  Arbitrary data to pass to connection
      // unsigned int options = 0,  ///<  options to pass to conneciton
      // OpalConnection::StringOptions * stringOptions  = NULL
    // );

    /** Execute garbage collection for endpoint.
        Returns PTrue if all garbage has been collected.
        Default behaviour deletes the objects in the connectionsActive list.
      */
    virtual PBoolean GarbageCollection();
  //@}

  /**@name Operations */
  //@{
    /**Find a connection that uses the specified token.
       This searches the endpoint for the connection that contains the token
       as provided by functions such as MakeConnection(). If not then it
       attempts to use the token as a OpalCall token and find a connection
       of the same class.
      */
    // PSafePtr<OpalMixerConnection> GetMixerConnectionWithLock(
      // const PString & token,     ///<  Token to identify connection
      // PSafetyMode mode = PSafeReadWrite
    // );

    /**Create a connection for the PCSS endpoint.
       The default implementation is to create a OpalMixerConnection.
      */
    // virtual OpalMixerConnection * CreateConnection(
      // PSafePtr<OpalMixerNode> node, ///<  Node the connection is in
      // OpalCall & call,              ///<  Owner of connection
      // void * userData,              ///<  Arbitrary data to pass to connection
      // unsigned options,
      // OpalConnection::StringOptions * stringOptions
    // );
  //@}

  /**@name Mixer Operations */
  //@{
    /**Add a new node.
       The info variable should be created on the heap and it is subsequently
       owned by the node. NULL can be passed if defaults are to be used.
	   Calls CreateNode.
      */
    // PSafePtr<OpalMixerNode> AddNode(
      // OpalMixerNodeInfo * info ///< Initial info for node
    // );

    /**Create a new node.
       This should create the new instance of the OpalMixerNode as required
       by the derived class, if any.
       The info variable should be created on the heap and it is subsequently
       owned by the node. NULL can be passed if defaults are to be used.
      */
    virtual OpalMixerNode * CreateNode(
      OpalMixerNodeInfo * info ///< Initial info for node
    );

    /**Find an existing node.
       This will search for the mixer node using GUID and then name.
      */
    // PSafePtr<OpalMixerNode> FindNode(
      // const PString & name,             ///< GUID or alias name for node
      // PSafetyMode mode = PSafeReference ///< Lock mode for returned pointer
    // );

    /**Remove a node.
       Shut down all active connections with node, remove its name 
	   associations and delete it.
      */
    void RemoveNode(
      OpalMixerNode & node ///< Initial info for node
    );
  //@}

  /**@name Member variable access */
  //@{
    /**Set default ad hoc node information.
       The pointer is passed to the CreateNode() function, so may be a
       reference to derived class, which a derived class of OpalMixerNode
       could use.

       Note if NULL, then ad hoc nodes are not created and incoming
       connections are refused. A user must ex[icitly call AddNode() to create
       a name that can be conected to.

       The version that takes a reference will utilise the CLone() function
       to create a copy of the mixer info.
      */
    void SetAdHocNodeInfo(
      const OpalMixerNodeInfo & info
    );
    void SetAdHocNodeInfo(
      OpalMixerNodeInfo * info
    );

    /**Get default ad hoc mode information.
       The pointer returned from this function is passed to the CreateNode()
       function, so may be a reference to derived class, which a derived class
       of OpalMixerNode could use.

       Note if NULL, then ad hoc nodes are not created and incoming
       connections are refused. A user must ex[icitly call AddNode() to create
       a name that can be conected to.

       Default bahaviour returns member variable m_adHocNodeInfo.
      */
    OpalMixerNodeInfo * GetAdHocNodeInfo();
  //@}

};


// ///////////////////////////////////////////////////////////////////////////////

// /** Mixer connection.
 // */
// class OpalMixerConnection : OpalLocalConnection
// {
  // public:
  // /**@name Construction */
  // //@{
    // /**Create a new connection.
     // */
    // // OpalMixerConnection(
      // // PSafePtr<OpalMixerNode> node, ///<  Node the connection is in
      // // OpalCall & call,              ///<  Owner calll for connection
      // // OpalMixerEndPoint & endpoint, ///<  Owner endpoint for connection
      // // void * userData,              ///<  Arbitrary data to pass to connection
      // // unsigned options,
      // // OpalConnection::StringOptions * stringOptions
    // // );
	
	// OpalMixerConnection();

    // /**Destroy connection.
     // */
    // ~OpalMixerConnection();
  // //@}

  // /**@name Overrides from OpalConnection */
  // //@{
    // /**Clean up the termination of the connection.
       // This function can do any internal cleaning up and waiting on background
       // threads that may be using the connection object.

       // Note that there is not a one to one relationship with the
       // OnEstablishedConnection() function. This function may be called without
       // that function being called. For example if SetUpConnection() was used
       // but the call never completed.

       // Classes that override this function should make sure they call the
       // ancestor version for correct operation.

       // An application will not typically call this function as it is used by
       // the OpalManager during a release of the connection.

       // The default behaviour calls the OpalEndPoint function of the same name.
      // */
    // virtual void OnReleased();

    // /**Get the data formats this connection is capable of operating.
       // This provides a list of media data format names that a
       // OpalMediaStream may be created in within this connection.

       // The default behaviour calls GetMediaFormats() on the endpoint.
      // */
    // virtual OpalMediaFormatList GetMediaFormats() const;

    // /**Open a new media stream.
       // This will create a media stream of an appropriate subclass as required
       // by the underlying connection protocol. For instance H.323 would create
       // an OpalRTPStream.

       // The sessionID parameter may not be needed by a particular media stream
       // and may be ignored. In the case of an OpalRTPStream it us used.

       // Note that media streams may be created internally to the underlying
       // protocol. This function is not the only way a stream can come into
       // existance.

       // The default behaviour is pure.
     // */
    // virtual OpalMediaStream * CreateMediaStream(
      // const OpalMediaFormat & mediaFormat, ///<  Media format for stream
      // unsigned sessionID,                  ///<  Session number for stream
      // PBoolean isSource                    ///<  Is a source stream
    // );

    // virtual void ApplyStringOptions(OpalConnection::StringOptions & stringOptions);
  // //@}

  // /**@name Operations */
  // //@{
    // /**Set this connection to listen only mode.
      // */
    // void SetListenOnly(
      // bool listenOnly   ///< New listen only state.
    // );

    // /**Get flag for this connection is in listen only mode.
      // */
    // bool GetListenOnly() const;

    // /**Get the node that this connection is being mxied in.
      // */
    // // PSafePtr<OpalMixerNode> GetNode() const;
  // //@}

// };


/**Mixer media stream.
   This class represents a media stream that will send/get media from a mixer.
 */
class OpalMixerMediaStream : OpalMediaStream
{
  private:
		OpalMixerMediaStream();
		
  public:
  /**@name Construction */
  //@{
    /**Construct a new media stream for mixer.
      */
    // OpalMixerMediaStream(
      // OpalConnection & conn,               ///<  Connection for media stream
      // const OpalMediaFormat & mediaFormat, ///<  Media format for stream
      // unsigned sessionID,                  ///<  Session number for stream
      // bool isSource,                       ///<  Is a source stream
      // PSafePtr<OpalMixerNode> node,        ///<  Mixer node to send data
      // bool listenOnly                      ///<  Effectively initial pause state
    // );

    /**Destroy stream.
      */
    ~OpalMixerMediaStream();
  //@}

  /**@name Overrides of OpalMediaStream class */
  //@{
    /**Open the media stream using the media format.
      */
    virtual PBoolean Open();

    /**Close the media stream.
      */
    virtual PBoolean Close();

    /**Write an RTP frame of data to the sink media stream.
       The default behaviour simply calls WriteData() on the data portion of the
       RTP_DataFrame and and sets the internal timestamp and marker from the
       member variables of the media stream class.
      */
    virtual PBoolean WritePacket(
      RTP_DataFrame & packet
    );

    /**Indicate if the media stream is synchronous.
       Returns PTrue for LID streams.
      */
    virtual PBoolean IsSynchronous() const;

    /**Indicate if the media stream requires a OpalMediaPatch thread (active patch).
       This is called on the source/sink stream and is passed the sink/source
       stream that the patch will initially be using. The function could
       conditionally require the patch thread to execute a thread reading and
       writing data, or prevent  it from doing so as it can do so in hardware
       in some way.

       The default behaviour returns true if a sink stream. If source stream
       then threading is from the mixer class.
      */
    virtual PBoolean RequiresPatchThread() const;
  //@}

  /**@name Member variable access */
  //@{
    /**Get the mixer node for this stream.
     */
    // PSafePtr<OpalMixerNode> GetNode();
  //@}

};


/** Mixer node.
    This class represents a group of connections that are being mixed.
  */
class OpalMixerNode /* : PSafeObject */
{
  public:
  /**@name Construction */
  //@{
    /**Create a new node.
     */
    OpalMixerNode(
      OpalMixerNodeManager & manager, ///< Manager for this node
      OpalMixerNodeInfo * info        ///< Configuration information
    );

    /**Destroy node.
     */
    ~OpalMixerNode();

    /**Shut down node.
       This clears all attached connections, removes all names and generally
       shuts the node down.
      */
    void ShutDown();
  //@}


  /**@name Operations */
  //@{
    /**Attach a connection.
      */
    void AttachConnection(
      OpalConnection * connection  ///< Connection to attach
    );

    /**Detach a connection.
      */
    void DetachConnection(
      OpalConnection * connection  ///< Connection to detach
    );

    /**Attach a stream for output.
      */
    bool AttachStream(
      OpalMixerMediaStream * stream     ///< Stream to attach
    );

    /**Detach a stream for output.
      */
    void DetachStream(
      OpalMixerMediaStream * stream     ///< Stream to detach
    );

    /**Write data to mixer.
      */
    bool WriteAudio(
      const OpalBaseMixer::Key_T & key, ///< key for mixer stream
      const RTP_DataFrame & input       ///< Input RTP data for media
    );

    /**Write data to mixer.
      */
    bool WriteVideo(
      const OpalBaseMixer::Key_T & key, ///< key for mixer stream
      const RTP_DataFrame & input       ///< Input RTP data for media
    );
  //@}

  /**@name Member variable access */
  //@{
    /**Get globally unique identifier for node.
      */
    const PGloballyUniqueID & GetGUID() const;

    /**Get list of names for this node.
      */
    const PStringList & GetNames() const;

    /**Add a name for this node.
      */
    void AddName(
      const PString & name
    );

    /**Remove a name for this node.
      */
    void RemoveName(
      const PString & name
    );

    /**Get count of connections.
       Note that as this value can change ata any moent, it is really not
       that useful and should definitely not be used for enumeration of the
       connections.
      */
    PINDEX GetConnectionCount() const;

    /**Get first connection in the connections list.
      */
    // PSafePtr<OpalConnection> GetFirstConnection(
      // PSafetyMode mode = PSafeReference
    // ) const;

    /**Get the raw audio accumulation buffer.
     */
    const OpalMixerNodeInfo & GetNodeInfo();

    /**Get the creation time of the node.
     */
    const PTime & GetCreationTime() const;
  //@}

};


///////////////////////////////////////////////////////////////////////////////
